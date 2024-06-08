/*
 * esc_pos_bluetooth
 * Created by Andrey Ushakov
 * 
 * Copyright (c) 2019-2020. All rights reserved.
 * See LICENSE for distribution and usage details.
 */

import 'dart:async';
import 'dart:io';
import 'package:rxdart/rxdart.dart';
import 'package:flutter_bluetooth_basic/flutter_bluetooth_basic.dart';
import './enums.dart';

/// Bluetooth printer
class PrinterBluetooth {
  PrinterBluetooth(this.device);
  final BluetoothDevice device;

  // String get name => device.name;
  // String get address => device.address;
  // int get type => device.type;
  // bool get connected => device.connected;
}

/// Printer Bluetooth Manager
class PrinterBluetoothManager {
  BluetoothManager bluetoothManager = BluetoothManager.instance;
  Future<bool> get isConnected => bluetoothManager.isConnected;
  // bool _isConnected = false;
  StreamSubscription? _scanResultsSubscription;
  StreamSubscription? _isScanningSubscription;
  PrinterBluetooth? _selectedPrinter;

  final BehaviorSubject<bool> _isScanning = BehaviorSubject.seeded(false);
  Stream<bool> get isScanningStream => _isScanning.stream;

  final BehaviorSubject<List<PrinterBluetooth>> _scanResults =
      BehaviorSubject.seeded([]);
  Stream<List<PrinterBluetooth>> get scanResults => _scanResults.stream;

  Future startScan(Duration timeout) async {
    _scanResults.add(<PrinterBluetooth>[]);
    _scanResultsSubscription = bluetoothManager.scanResults.listen((devices) {
      _scanResults.add(devices.map((d) => PrinterBluetooth(d)).toList());
    });

    _isScanningSubscription =
        bluetoothManager.isScanning.listen((isScanningCurrent) async {
      // If isScanning value changed (scan just stopped)
      if ((_isScanning.value !=null)&& !isScanningCurrent) {
        _scanResultsSubscription?.cancel();
        _isScanningSubscription?.cancel();
      }
      _isScanning.add(isScanningCurrent);
    });

    await bluetoothManager.startScan(timeout: timeout).catchError((e) {
      throw  Exception(e.message);
    });

  }

  void stopScan() async {
    await bluetoothManager.stopScan();
  }

  Future<bool> selectPrinter(PrinterBluetooth printer) async {
    // await _bluetoothManager.disconnect();
    _selectedPrinter = printer;

    // Connect
    if(_selectedPrinter != null) {
      await bluetoothManager.connect(_selectedPrinter!.device);
    }
    // _isConnected = await _bluetoothManager.isConnected;
    await Future.delayed(const Duration(milliseconds: 500));

    return await bluetoothManager.isConnected;
  }

  Future<PosPrintResult> writeBytes(
    List<int> bytes, {
    int chunkSizeBytes = 20,
    int queueSleepTimeMs = 20,
  }) async {
    final Completer<PosPrintResult> completer = Completer();

    if (_selectedPrinter == null) {
      return Future<PosPrintResult>.value(PosPrintResult.printerNotSelected);
    } else if (_isScanning.value!=null) {
      return Future<PosPrintResult>.value(PosPrintResult.scanInProgress);
    }

    // We have to rescan before connecting, otherwise we can connect only once
    // await _bluetoothManager.startScan(timeout: Duration(seconds: 5));
    // await _bluetoothManager.stopScan();

    // Subscribe to the events
    // _bluetoothManager.state.listen((state) async {
    //   print('_bluetoothManager state -> ${state.toString()}');
    //   switch (state) {
    //     case BluetoothManager.CONNECTED:
    //       break;
    //     case BluetoothManager.DISCONNECTED:
    //       // _isConnected = false;
    //       break;
    //     default:
    //       break;
    //   }
    // });

    final len = bytes.length;
    List<List<int>> chunks = [];
    for (var i = 0; i < len; i += chunkSizeBytes) {
      var end = (i + chunkSizeBytes < len) ? i + chunkSizeBytes : len;
      chunks.add(bytes.sublist(i, end));
    }

    for (var i = 0; i < chunks.length; i += 1) {
      await bluetoothManager.writeData(chunks[i]);
      sleep(Duration(milliseconds: queueSleepTimeMs));
    }

    completer.complete(PosPrintResult.success);

    // Printing timeout
    Future<dynamic>.delayed(const Duration(seconds: 5)).then((v) async {
      if (!completer.isCompleted) {
        completer.complete(PosPrintResult.timeout);
      }
    });

    return completer.future;
  }

}
