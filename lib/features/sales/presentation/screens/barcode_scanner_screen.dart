import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final bool continuousMode;

  const BarcodeScannerScreen({super.key, this.continuousMode = false});

  static const stopContinuousResult = '__stop_continuous_scanner__';

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  bool _resolved = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear código'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        actions: [
          if (widget.continuousMode)
            IconButton(
              tooltip: 'Desactivar escaneo continuo',
              onPressed: () => Navigator.pop(
                context,
                BarcodeScannerScreen.stopContinuousResult,
              ),
              icon: const Icon(Icons.videocam_off_rounded),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_resolved) return;
              final value = capture.barcodes
                  .map((barcode) => barcode.rawValue)
                  .whereType<String>()
                  .firstOrNull;
              if (value == null || value.isEmpty) return;
              _resolved = true;
              Navigator.pop(context, value);
            },
          ),
          Center(
            child: Container(
              width: 280,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 54,
            child: Text(
              'Coloca el código de barras dentro del recuadro',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
