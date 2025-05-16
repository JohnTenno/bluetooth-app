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
      title: 'raw',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
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
  bool isConnecting = false;
  String targetDeviceName = "XM-15";
  String connectionStatus = "Desconectado";
  List<BluetoothDevice> devices = [];
  BluetoothDevice? selectedDevice;

  // Controladores para campos de entrada
  final TextEditingController _messageController = TextEditingController();
  String receivedData = "";

  @override
  void initState() {
    super.initState();

    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() => _bluetoothState = state);
    });

    FlutterBluetoothSerial.instance.onStateChanged().listen((state) {
      setState(() => _bluetoothState = state);
      if (state == BluetoothState.STATE_ON) {
        getPairedDevices();
      }
    });

    enableBluetooth();
  }

  @override
  void dispose() {
    if (isConnected) {
      disconnect();
    }
    _messageController.dispose();
    super.dispose();
  }

  Future<void> enableBluetooth() async {
    if (_bluetoothState != BluetoothState.STATE_ON) {
      await FlutterBluetoothSerial.instance.requestEnable();
    }
    await getPairedDevices();
  }

  Future<void> getPairedDevices() async {
    List<BluetoothDevice> bondedDevices =
        await FlutterBluetoothSerial.instance.getBondedDevices();

    setState(() {
      devices = bondedDevices;
      if (devices.isNotEmpty) {
        selectedDevice = devices.firstWhere(
          (d) => d.name == targetDeviceName,
          orElse: () => devices.first,
        );
      }
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    if (isConnecting || isConnected) return;

    setState(() {
      isConnecting = true;
      connectionStatus = "Conectando...";
    });

    try {
      connection = await BluetoothConnection.toAddress(device.address);

      setState(() {
        isConnected = true;
        isConnecting = false;
        connectionStatus = "Conectado a ${device.name}";
      });

      connection!.input!
          .listen((data) {
            setState(() {
              receivedData = String.fromCharCodes(data);
            });
          })
          .onDone(() {
            disconnect();
          });
    } catch (e) {
      setState(() {
        connectionStatus = "Error de conexión: ${e.toString()}";
        isConnecting = false;
      });
    }
  }

  void disconnect() {
    if (connection != null) {
      connection!.dispose();
      setState(() {
        isConnected = false;
        connectionStatus = "Desconectado";
      });
    }
  }

  void sendCommand(String command) {
    if (connection != null && isConnected) {
      connection!.output.add(Uint8List.fromList("$command\n".codeUnits));
      connection!.output.allSent.then((_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Comando enviado: $command")));
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No hay conexión Bluetooth activa")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("sexo"),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: getPairedDevices),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      "Estado: $connectionStatus",
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 10),
                    if (devices.isNotEmpty)
                      DropdownButton<BluetoothDevice>(
                        value: selectedDevice,
                        items:
                            devices.map((device) {
                              return DropdownMenuItem(
                                value: device,
                                child: Text(
                                  "${device.name} (${device.address})",
                                ),
                              );
                            }).toList(),
                        onChanged: (device) {
                          setState(() {
                            selectedDevice = device;
                          });
                        },
                        hint: Text("Selecciona dispositivo"),
                        isExpanded: true,
                      ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed:
                              isConnected
                                  ? null
                                  : () {
                                    if (selectedDevice != null) {
                                      connectToDevice(selectedDevice!);
                                    }
                                  },
                          child: Text("Conectar"),
                        ),
                        ElevatedButton(
                          onPressed: isConnected ? disconnect : null,
                          child: Text("Desconectar"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text("Controles", style: TextStyle(fontSize: 18)),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () => sendCommand("LED_ON"),
                          child: Text("Encender LED"),
                        ),
                        ElevatedButton(
                          onPressed: () => sendCommand("LED_OFF"),
                          child: Text("Apagar LED"),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        labelText: "Mensaje personalizado",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        if (_messageController.text.isNotEmpty) {
                          sendCommand(_messageController.text);
                          _messageController.clear();
                        }
                      },
                      child: Text("Enviar mensaje"),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Datos recibidos", style: TextStyle(fontSize: 18)),
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      height: 100,
                      child: SingleChildScrollView(child: Text(receivedData)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
