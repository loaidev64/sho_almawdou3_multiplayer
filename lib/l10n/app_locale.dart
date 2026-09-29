mixin AppLocale {
  static const String appName = 'شو الموضوع';

  static const String homeTitle = 'homeTitle';
  static const String host = 'host';
  static const String join = 'join';
  static const String leave = 'leave';
  static const String connect = 'connect';
  static const String statusIdle = 'statusIdle';
  static const String statusHosting = 'statusHosting';
  static const String statusScanning = 'statusScanning';
  static const String statusConnected = 'statusConnected';
  static const String statusNoServer = 'statusNoServer';
  static const String statusNotConnected = 'statusNotConnected';
  static const String clientsCount = 'clientsCount';
  static const String messageHint = 'messageHint';
  static const String messagesEmpty = 'messagesEmpty';
  static const String send = 'send';
  static const String manualHint = 'manualHint';
  static const String you = 'you';
  static const String peer = 'peer';

  static const Map<String, dynamic> ar = <String, dynamic>{
    homeTitle: 'شو الموضوع',
    host: 'استضافة',
    join: 'انضام',
    leave: 'مغادرة',
    connect: 'اتصال',
    statusIdle: 'جاهز — استضف أو انضم للبدء',
    statusHosting: 'الاستضافة نشطة',
    statusScanning: 'جارٍ البحث عن مضيف...',
    statusConnected: 'متصل بالمضيف',
    statusNoServer: 'لم يتم العثور على مضيف',
    statusNotConnected: 'لا يوجد اتصال',
    clientsCount: 'المتصلون: %a',
    messageHint: 'اكتب رسالة...',
    messagesEmpty: 'لا توجد رسائل بعد — استضِف أو انضم ثم أرسل رسالة',
    send: 'إرسال',
    manualHint: '192.168.1.5:8080',
    you: 'أنت',
    peer: 'الجهاز الآخر',
  };
}
