import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:local_websocket/local_websocket.dart';
import 'package:reel_text/reel_text.dart';

import '../l10n/app_locale.dart';

enum _Role { none, host, guest }

class _Message {
  _Message({required this.text, required this.fromSelf, required this.at});

  final String text;
  final bool fromSelf;
  final DateTime at;
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const int port = 8080;
  static const Duration scanTimeout = Duration(seconds: 15);

  final TextEditingController _messageInput = TextEditingController();
  final TextEditingController _manualInput = TextEditingController();
  final List<_Message> _messages = <_Message>[];
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  Server? _server;
  Client? _client;
  StreamSubscription<List<DiscoveredServer>>? _scanSubscription;
  Timer? _scanTimer;

  _Role _role = _Role.none;
  bool _busy = false;
  bool _connecting = false;
  bool _scanning = false;
  bool _scanFailed = false;
  int _clientsCount = 0;
  String _hostAddress = '';

  @override
  void dispose() {
    unawaited(_teardown());
    _messageInput.dispose();
    _manualInput.dispose();
    super.dispose();
  }

  Future<void> _teardown() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    for (final StreamSubscription<dynamic> sub
        in List<StreamSubscription<dynamic>>.of(_subscriptions)) {
      await sub.cancel();
    }
    _subscriptions.clear();
    final Server? server = _server;
    _server = null;
    final Client? client = _client;
    _client = null;
    if (server != null) {
      await server.dispose();
    }
    if (client != null) {
      await client.dispose();
    }
  }

  String _now() => DateTime.now().toIso8601String();

  String _formatTime(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  Future<({String subnet, String address})?> _ownNetwork() async {
    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      const List<String> skipPrefixes = <String>[
        'docker',
        'veth',
        'br-',
        'tun',
        'virbr',
        'rndis',
        'usb',
      ];
      for (final bool preferredPass in const <bool>[true, false]) {
        for (final NetworkInterface interface in interfaces) {
          final String name = interface.name.toLowerCase();
          final bool skipped =
              skipPrefixes.any((String p) => name.startsWith(p));
          final bool preferred = RegExp(r'^(eth|ens|enp|en|wlan|wlp)')
              .hasMatch(name);
          if (skipped || (preferredPass && !preferred)) {
            continue;
          }
          for (final InternetAddress address in interface.addresses) {
            if (address.isLoopback) continue;
            final List<String> parts = address.address.split('.');
            if (parts.length == 4) {
              return (
                subnet: '${parts[0]}.${parts[1]}.${parts[2]}',
                address: address.address,
              );
            }
          }
        }
      }
    } catch (error) {
      debugPrint('[WS-DEBUG] network lookup failed: $error ${_now()}');
    }
    return null;
  }

  void _addMessage(String text, {required bool fromSelf}) {
    if (!mounted) return;
    setState(() {
      _messages.insert(
        0,
        _Message(text: text, fromSelf: fromSelf, at: DateTime.now()),
      );
    });
  }

  Future<void> _host() async {
    if (_busy || _role != _Role.none) return;
    setState(() {
      _busy = true;
      _scanning = false;
      _scanFailed = false;
    });
    debugPrint('[WS-DEBUG] starting host on 0.0.0.0:$port ${_now()}');
    try {
      await _teardown();
      final Server server = Server(
        echo: false,
        details: <String, dynamic>{'name': AppLocale.appName},
      );
      await server.start(InternetAddress.anyIPv4.address, port: port);
      _server = server;
      _subscriptions.add(server.messageStream.listen((dynamic message) {
        debugPrint('[WS-DEBUG] host received "$message" ${_now()}');
        _addMessage('$message', fromSelf: false);
      }));
      _subscriptions.add(server.clientsStream.listen((Set<Client> clients) {
        debugPrint('[WS-DEBUG] host clients=${clients.length} ${_now()}');
        if (!mounted) return;
        setState(() => _clientsCount = clients.length);
      }));
      final ({String subnet, String address})? network =
          await _ownNetwork();
      if (!mounted) return;
      setState(() {
        _role = _Role.host;
        _busy = false;
        _clientsCount = 0;
        _hostAddress = network?.address ?? '';
      });
      debugPrint(
        '[WS-DEBUG] hosting ${server.address} local=${network?.address} ${_now()}',
      );
    } catch (error, stackTrace) {
      debugPrint('[WS-DEBUG] host failed: $error $stackTrace');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _scanFailed = true;
      });
    }
  }

  Future<void> _join() async {
    if (_busy || _role != _Role.none) return;
    await _teardown();
    if (!mounted) return;
    setState(() {
      _busy = true;
      _scanning = true;
      _scanFailed = false;
    });
    final ({String subnet, String address})? network = await _ownNetwork();
    if (network == null) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _scanning = false;
        _scanFailed = true;
      });
      return;
    }
    debugPrint('[WS-DEBUG] scanning subnet ${network.subnet}:$port ${_now()}');
    _scanSubscription =
        Scanner.scan(network.subnet, port: port)
            .listen((List<DiscoveredServer> servers) {
      if (_client != null || _connecting) return;
      if (servers.isEmpty) {
        debugPrint('[WS-DEBUG] scan: no server yet ${_now()}');
        return;
      }
      final DiscoveredServer found = servers.first;
      debugPrint(
        '[WS-DEBUG] scan found ${found.path} details=${found.details} ${_now()}',
      );
      _connecting = true;
      unawaited(_connect(found.path).whenComplete(() => _connecting = false));
    });
    _scanTimer = Timer(scanTimeout, () {
      if (_client != null || !mounted || !_scanning) return;
      debugPrint('[WS-DEBUG] scan timed out ${_now()}');
      unawaited(_teardown());
      if (!mounted) return;
      setState(() {
        _busy = false;
        _scanning = false;
        _scanFailed = true;
      });
    });
  }

  Future<void> _connectManual() async {
    final String path = _normalizePath(_manualInput.text);
    if (path.isEmpty || _busy || _connecting) return;
    await _teardown();
    if (!mounted) return;
    setState(() {
      _busy = true;
      _scanning = true;
      _scanFailed = false;
    });
    _connecting = true;
    await _connect(path);
    _connecting = false;
  }

  String _normalizePath(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('ws://') || value.startsWith('wss://')) {
      return value.endsWith('/ws') ? value : '$value/ws';
    }
    return 'ws://$value/ws';
  }

  Future<void> _connect(String path) async {
    debugPrint('[WS-DEBUG] connecting to $path ${_now()}');
    try {
      final Client client = Client(
        details: <String, String>{'device': 'flutter'},
      );
      await client.connect(path);
      _scanTimer?.cancel();
      _scanTimer = null;
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _client = client;
      _subscriptions.add(client.messageStream.listen((dynamic message) {
        debugPrint('[WS-DEBUG] guest received "$message" ${_now()}');
        _addMessage('$message', fromSelf: false);
      }));
      _subscriptions
          .add(client.connectionStream.listen((ClientConnectionStatus status) {
        debugPrint('[WS-DEBUG] guest connection=$status ${_now()}');
        if (!mounted) return;
        if (status == ClientConnectionStatus.disconnected &&
            _role == _Role.guest) {
          setState(() {
            _role = _Role.none;
            _busy = false;
            _scanning = false;
          });
        }
      }));
      if (!mounted) return;
      setState(() {
        _role = _Role.guest;
        _busy = false;
        _scanning = false;
        _scanFailed = false;
      });
      debugPrint('[WS-DEBUG] connected as ${client.uid} ${_now()}');
    } catch (error) {
      debugPrint('[WS-DEBUG] connect failed: $error ${_now()}');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _scanning = false;
        _scanFailed = true;
      });
    }
  }

  Future<void> _leave() async {
    debugPrint('[WS-DEBUG] leaving ${_now()}');
    await _teardown();
    if (!mounted) return;
    setState(() {
      _role = _Role.none;
      _busy = false;
      _scanning = false;
      _scanFailed = false;
      _clientsCount = 0;
      _hostAddress = '';
    });
  }

  void _send() {
    final String text = _messageInput.text.trim();
    if (text.isEmpty) return;
    final Server? server = _server;
    final Client? client = _client;
    if (_role == _Role.host && server != null) {
      server.send(text);
      _addMessage(text, fromSelf: true);
      debugPrint('[WS-DEBUG] host sent "$text" ${_now()}');
      _messageInput.clear();
      return;
    }
    if (_role == _Role.guest && client != null) {
      client.send(text);
      _addMessage(text, fromSelf: true);
      debugPrint('[WS-DEBUG] guest sent "$text" ${_now()}');
      _messageInput.clear();
      return;
    }
    debugPrint('[WS-DEBUG] send skipped, no connection ${_now()}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocale.statusNotConnected.getString(context))),
    );
  }

  String _statusText(BuildContext context) {
    if (_scanning) return AppLocale.statusScanning.getString(context);
    switch (_role) {
      case _Role.host:
        return AppLocale.statusHosting.getString(context);
      case _Role.guest:
        return AppLocale.statusConnected.getString(context);
      case _Role.none:
        return _scanFailed
            ? AppLocale.statusNoServer.getString(context)
            : AppLocale.statusIdle.getString(context);
    }
  }

  Widget _buildStatusCard(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: <Widget>[
          ReelText(
            key: const ValueKey('status_text'),
            _statusText(context),
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (_role == _Role.host) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              key: const ValueKey('host_info'),
              '$_hostAddress:$port · '
              '${Strings.format(AppLocale.clientsCount.getString(context), <dynamic>[_clientsCount])}',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: _role == _Role.none
                ? <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('host_button'),
                        onPressed: _busy ? null : _host,
                        icon: const Icon(Icons.wifi_tethering),
                        label: Text(AppLocale.host.getString(context)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('join_button'),
                        onPressed: _busy ? null : _join,
                        icon: const Icon(Icons.travel_explore),
                        label: Text(AppLocale.join.getString(context)),
                      ),
                    ),
                  ]
                : <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('leave_button'),
                        onPressed: _leave,
                        icon: const Icon(Icons.logout),
                        label: Text(AppLocale.leave.getString(context)),
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualRow(BuildContext context) {
    if (_role != _Role.none || _scanning) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              key: const ValueKey('manual_input'),
              controller: _manualInput,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: AppLocale.manualHint.getString(context),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            key: const ValueKey('manual_connect_button'),
            onPressed: _busy ? null : _connectManual,
            icon: const Icon(Icons.link),
            label: Text(AppLocale.connect.getString(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(_Message message, BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color bubbleColor = message.fromSelf
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    return Padding(
      key: ValueKey('message_${message.at.microsecondsSinceEpoch}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Align(
        alignment: message.fromSelf
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: message.fromSelf
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${message.fromSelf ? AppLocale.you.getString(context) : AppLocale.peer.getString(context)} · ${_formatTime(message.at)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: message.fromSelf
                      ? theme.colorScheme.onPrimary.withValues(alpha: 0.8)
                      : theme.hintColor,
                ),
              ),
              Text(
                message.text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: message.fromSelf
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(AppLocale.homeTitle.getString(context)),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildStatusCard(context),
            _buildManualRow(context),
            const Divider(height: 1),
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        key: const ValueKey('messages_empty'),
                        AppLocale.messagesEmpty.getString(context),
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      key: const ValueKey('message_list'),
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (BuildContext context, int index) =>
                          _buildMessage(_messages[index], context),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      key: const ValueKey('message_input'),
                      controller: _messageInput,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: AppLocale.messageHint.getString(context),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const ValueKey('send_button'),
                    onPressed: _send,
                    tooltip: AppLocale.send.getString(context),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
