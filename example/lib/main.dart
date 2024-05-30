import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter/services.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:flutter_html_to_pdf/flutter_html_to_pdf.dart';
import 'package:image/image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void _incrementCounter() {
    printP88();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child:Text("Welcome to Flutter ESC POS Utils!"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}


Future<void> printP88() async {
  final profile = await CapabilityProfile.load();
  PaperSize mm80 = PaperSize.mm80;
  final printer = NetworkPrinter(mm80, profile);
  const ip = "192.168.1.100";
  final PosPrintResult res = await printer.connect(ip, port: 9100);
  final font =await rootBundle.load("assets/siemreab.ttf");
  final fontData = font.buffer.asUint8List();
  if (res == PosPrintResult.success) {
    printer.qrcode("hello");
    final List<String> cols = <String>[
      'លេខកូដ',
      'ឈ្មោះទំនិញ',
      'តម្លៃ',
      'ចំនួន',
      'តម្លៃសរុប'
    ];
    final List<Map<String, dynamic>> rows = [
      {
        "1": {'1', 'សំណុំទឹកដោះគោ', '1.00', '2', '2.00'}
      },
      {
        "2": {'2', 'សំណុំទឹកដោលគោ', '1.00', '3', '2.00'}
      },
    ];
    /// font style text khmer
    await printer.textUft8("វិស័យអប់រំគឺជាវិស័យមួយចំបងក្នុងការរុញច្រាននិងបណ្តុះបណ្តាលធនាធានមនុស្ស ទាំងបច្ចុប្បន្ននិងអនាគតដើម្បីបំរើដល់ដល់ការងារសង្គម ។");
    printer.hr();
    await printer.rowUft8(cols);
    for(final row in rows){
      final List<String> rowList = [];
      final values = row.values as List<String>;
      printer.rowUft8(values);
    }
    printer.text("Thank you...!",
        styles: const PosStyles(align: PosAlign.center));
    printer.feed(2);
    printer.cut();
    printer.disconnect();
  } else {
    throw Exception("Can't connect to printer");
  }
}

Future<void> networkPrint() async {
  final profile = await CapabilityProfile.load(name: 'Zy306');
  PaperSize mm80 = PaperSize.mm80;
  final printer = NetworkPrinter(mm80, profile);
  const ip = "192.168.3.100";
  final PosPrintResult res = await printer.connect(ip, port: 9100);
}

Future<Uint8List> getBillImage(String label,
    {double fontSize = 26,
    FontWeight fontWeight = FontWeight.w600,
    double maxWidth = 372}) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);

  /// Background
  final backgroundPaint = Paint()..color = Colors.white;
  final backgroundRect = Rect.fromLTRB(maxWidth, 10000, 0, 0);
  final backgroundPath = Path()
    ..addRRect(
      RRect.fromRectAndRadius(backgroundRect, const Radius.circular(0)),
    )
    ..close();
  canvas.drawPath(backgroundPath, backgroundPaint);

  //Title
  final ticketNum = TextPainter(
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.left,
    text: TextSpan(
      text: label,
      style: TextStyle(
          color: Colors.black, fontSize: fontSize, fontWeight: fontWeight),
    ),
  );
  ticketNum
    ..layout(
      maxWidth: maxWidth,
    )
    ..paint(
      canvas,
      const Offset(0, 0),
    );
  canvas.restore();
  final picture = recorder.endRecording();
  final pngBytes = await (await picture.toImage(
          maxWidth.toInt(), ticketNum.height.toInt() + 5))
      .toByteData(format: ImageByteFormat.png);
  return pngBytes!.buffer.asUint8List();
}
