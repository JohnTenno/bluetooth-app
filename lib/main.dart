import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:typed_data';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Arduino',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: BluetoothPage(),
    );
  }
}

class BluetoothPage extends StatefulWidget {
  @override
  _BluetoothPageState createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  BluetoothConnection? connection;
  bool isConnected = false;
  String targetDeviceName = "HC-05"; 

  @override
  void initState() {
    super.initState();

    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() => _bluetoothState = state);
    });

    FlutterBluetoothSerial.instance.onStateChanged().listen((state) {
      setState(() => _bluetoothState = state);
    });

    enableBluetooth();
  }

  Future<void> enableBluetooth() async {
    if (_bluetoothState != BluetoothState.STATE_ON) {
      await FlutterBluetoothSerial.instance.requestEnable();
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      connection = await BluetoothConnection.toAddress(device.address);
      print('Connected to the device');
      setState(() => isConnected = true);

      connection!.input!.listen((data) {
        print('Received: ${String.fromCharCodes(data)}');
      });
    } catch (e) {
      print('Cannot connect, exception: $e');
    }
  }

  void sendCommand(String command) {
    if (connection != null && isConnected) {
      connection!.output.add(Uint8List.fromList("$command\n".codeUnits));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Control Arduino por Bluetooth")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () async {
              var devices =
                  await FlutterBluetoothSerial.instance.getBondedDevices();
              var device = devices.firstWhere(
                (d) => d.name == targetDeviceName,
                orElse: () => devices.first,
              );
              await connectToDevice(device);
            },
            child: Text("Conectar al módulo"),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => sendCommand("LED_ON"),
                child: Text("Encender LED"),
              ),
              SizedBox(width: 20),
              ElevatedButton(
                onPressed: () => sendCommand("LED_OFF"),
                child: Text("Apagar LED"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
