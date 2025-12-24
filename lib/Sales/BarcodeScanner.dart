import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:maxbillup/utils/translation_helper.dart';

class BarcodeScannerPage extends StatefulWidget {
  final Function(String) onBarcodeScanned;
  final String title;

  const BarcodeScannerPage({
    super.key,
    required this.onBarcodeScanned,
    this.title = 'Scan Barcode',
  });

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage>
    with SingleTickerProviderStateMixin {
  late MobileScannerController cameraController;
  bool _isScanning = true;
  String _lastScannedCode = '';
  int _scannedCount = 0;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Initialize camera controller - ONLY 1D barcode formats (bars, not text)
    cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      formats: [
        // Standard retail barcodes
        BarcodeFormat.ean13, // Most common: 13 digits
        BarcodeFormat.ean8, // Short version: 8 digits
        BarcodeFormat.upcA, // US/Canada: 12 digits
        BarcodeFormat.upcE, // Short UPC: 8 digits
        // Industrial/warehouse barcodes
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.itf,
        BarcodeFormat.codabar,
      ],
    );

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    cameraController.dispose();
    super.dispose();
  }

  void _handleBarcodeScan(String barcode) {
    if (!_isScanning || barcode.isEmpty) return;

    // Prevent duplicate scans
    if (barcode == _lastScannedCode) return;

    setState(() {
      _isScanning = false; // Temporarily disable scanning
      _lastScannedCode = barcode;
      _scannedCount++;
    });

    // Call the callback to process barcode
    widget.onBarcodeScanned(barcode);

    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanned: $barcode'),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(milliseconds: 1000),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    // Re-enable scanning after 1 second
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _isScanning = true;
          _lastScannedCode = '';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF2F7CF6),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(cameraController.torchEnabled
                ? Icons.flash_on
                : Icons.flash_off),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: cameraController,
            errorBuilder: (context, error, child) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 80, color: Colors.red),
                    const SizedBox(height: 20),
                    const Text(
                      'Camera Error',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        error.errorDetails?.message ??
                            'Unable to access camera',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2F7CF6),
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              );
            },
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && _isScanning) {
                // Filter to get only valid barcodes (not text/OCR)
                final validBarcodes = barcodes.where((barcode) {
                  // Only accept proper barcode formats, NOT text or unknown
                  final isValidFormat = barcode.format == BarcodeFormat.ean13 ||
                      barcode.format == BarcodeFormat.ean8 ||
                      barcode.format == BarcodeFormat.upcA ||
                      barcode.format == BarcodeFormat.upcE ||
                      barcode.format == BarcodeFormat.code128 ||
                      barcode.format == BarcodeFormat.code39 ||
                      barcode.format == BarcodeFormat.code93 ||
                      barcode.format == BarcodeFormat.codabar ||
                      barcode.format == BarcodeFormat.itf;

                  // Reject if it's text type or unknown format
                  final isNotText = barcode.type != BarcodeType.text &&
                      barcode.format != BarcodeFormat.unknown;

                  // Additional check: valid barcodes are usually 8-14 digits
                  final hasValidLength = barcode.rawValue != null &&
                      barcode.rawValue!.length >= 8 &&
                      barcode.rawValue!.length <= 14;

                  return isValidFormat && isNotText && hasValidLength;
                }).toList();

                if (validBarcodes.isNotEmpty) {
                  final barcode = validBarcodes.first;
                  if (barcode.rawValue != null &&
                      barcode.rawValue!.isNotEmpty) {
                    print(
                        'Valid barcode detected: ${barcode.rawValue} (Format: ${barcode.format})');
                    _handleBarcodeScan(barcode.rawValue!);
                  }
                } else if (barcodes.isNotEmpty) {
                  // Log rejected detections for debugging
                  final rejected = barcodes.first;
                  print(
                      'Rejected detection: ${rejected.rawValue} (Format: ${rejected.format}, Type: ${rejected.type})');
                }
              }
            },
          ),

          // Overlay with scanning area and animated line
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                painter: ScannerOverlay(
                  scanAreaSize: screenWidth * 0.7,
                  animationValue: _animation.value,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),

          // Instructions and scan count
          Positioned(
            bottom: screenHeight * 0.1,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Scanning status indicator
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isScanning
                          ? const Color(0xFF2F7CF6).withValues(alpha: 0.9)
                          : const Color(0xFFFF9800).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isScanning
                              ? Icons.qr_code_scanner
                              : Icons.pause_circle_outline,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isScanning ? 'Ready to Scan' : 'Processing...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Scan counter
                  if (_scannedCount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Scanned: $_scannedCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // Instructions
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: const [
                        Text(
                          '📊 Point at the BARCODE LINES',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Not the numbers below',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for scanner overlay
class ScannerOverlay extends CustomPainter {
  final double scanAreaSize;
  final double animationValue;

  ScannerOverlay({
    required this.scanAreaSize,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scanAreaLeft = (size.width - scanAreaSize) / 2;
    final double scanAreaTop = (size.height - scanAreaSize) / 2;
    final Rect scanArea =
        Rect.fromLTWH(scanAreaLeft, scanAreaTop, scanAreaSize, scanAreaSize);

    // Draw dark overlay
    final Paint backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(
              RRect.fromRectAndRadius(scanArea, const Radius.circular(16)))
          ..close(),
      ),
      backgroundPaint,
    );

    // Draw scanning line
    final Paint scanLinePaint = Paint()
      ..color = const Color(0xFF2F7CF6).withValues(alpha: 0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final double scanLineY = scanAreaTop + (scanAreaSize * animationValue);

    // Draw the animated scanning line
    canvas.drawLine(
      Offset(scanAreaLeft + 10, scanLineY),
      Offset(scanAreaLeft + scanAreaSize - 10, scanLineY),
      scanLinePaint,
    );

    // Draw glow effect on scan line
    final Paint glowPaint = Paint()
      ..color = const Color(0xFF2F7CF6).withValues(alpha: 0.3)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawLine(
      Offset(scanAreaLeft + 10, scanLineY),
      Offset(scanAreaLeft + scanAreaSize - 10, scanLineY),
      glowPaint,
    );

    // Draw border (full frame)
    final Paint framePaint = Paint()
      ..color = const Color(0xFF2F7CF6).withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanArea, const Radius.circular(16)),
      framePaint,
    );

    // Draw corner highlights
    final Paint cornerPaint = Paint()
      ..color = const Color(0xFF2F7CF6)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double cornerLength = 40;

    // Top-left corner
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + 16),
      Offset(scanAreaLeft, scanAreaTop + cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + 16, scanAreaTop),
      Offset(scanAreaLeft + cornerLength, scanAreaTop),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + 16),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize - 16, scanAreaTop),
      Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize - 16),
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize - cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + 16, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft + cornerLength, scanAreaTop + scanAreaSize),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize - 16),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize - cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize - 16, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop + scanAreaSize),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(ScannerOverlay oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

