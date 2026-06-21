import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Возвращает отсканированный код (String) при успешном сканировании
class AddMedicineBarcodeScreen extends StatefulWidget {
  const AddMedicineBarcodeScreen({super.key});

  @override
  State<AddMedicineBarcodeScreen> createState() =>
      _AddMedicineBarcodeScreenState();
}

class _AddMedicineBarcodeScreenState extends State<AddMedicineBarcodeScreen> {
  final MobileScannerController _controller = MobileScannerController(
    // Поддерживаемые форматы штрих-кодов для лекарств
    formats: [
      BarcodeFormat.ean13,      // EAN-13 (самый распространённый)
      BarcodeFormat.ean8,       // EAN-8 (короткие коды)
      BarcodeFormat.upcA,       // UPC-A (американский стандарт)
      BarcodeFormat.code128,    // Code128 (реже)
    ],
  );

  bool _isProcessing = false;
  bool _isTorchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканировать штрих-код'),
        centerTitle: true,
        actions: [
          // Кнопка включения/выключения фонарика
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() {
                _isTorchOn = !_isTorchOn;
              });
            },
          ),
          // Кнопка переключения камеры (фронтальная/основная)
          IconButton(
            icon: const Icon(Icons.switch_camera, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Камера со сканером
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Оверлей с рамкой сканирования
          _buildOverlay(),

          // Инструкция
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Наведите камеру на штрих-код упаковки',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          // Индикатор обработки
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Обработка...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    final size = MediaQuery.of(context).size;
    final scanWidth = size.width * 0.8;
    final scanHeight = size.height * 0.25;
    final scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanWidth,
      height: scanHeight,
    );

    return CustomPaint(
      painter: _ScannerOverlayPainter(scanRect),
      child: Container(),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    final code = barcode?.rawValue;
    if (code == null) return;

    setState(() => _isProcessing = true);

    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      // Возвращаем отсканированный код на предыдущий экран
      Navigator.pop(context, code);
    }
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Rect scanRect;

  _ScannerOverlayPainter(this.scanRect);

  @override
  void paint(Canvas canvas, Size size) {
    final darkPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final outerPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(scanRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(outerPath, darkPaint);

    final borderPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    canvas.drawRect(scanRect, borderPaint);

    // Уголки рамки
    final cornerPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    const cornerLength = 30.0;
    const cornerGap = 5.0;


    canvas.drawLine(
      Offset(scanRect.left - cornerGap, scanRect.top),
      Offset(scanRect.left + cornerLength, scanRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanRect.left, scanRect.top - cornerGap),
      Offset(scanRect.left, scanRect.top + cornerLength),
      cornerPaint,
    );


    canvas.drawLine(
      Offset(scanRect.right + cornerGap, scanRect.top),
      Offset(scanRect.right - cornerLength, scanRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanRect.right, scanRect.top - cornerGap),
      Offset(scanRect.right, scanRect.top + cornerLength),
      cornerPaint,
    );


    canvas.drawLine(
      Offset(scanRect.left - cornerGap, scanRect.bottom),
      Offset(scanRect.left + cornerLength, scanRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanRect.left, scanRect.bottom + cornerGap),
      Offset(scanRect.left, scanRect.bottom - cornerLength),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(scanRect.right + cornerGap, scanRect.bottom),
      Offset(scanRect.right - cornerLength, scanRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanRect.right, scanRect.bottom + cornerGap),
      Offset(scanRect.right, scanRect.bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}