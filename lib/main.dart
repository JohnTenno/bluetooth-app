import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Control',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: Colors.indigo,
          secondary: Colors.indigoAccent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.all(Colors.indigoAccent),
          trackColor: MaterialStateProperty.all(Colors.indigo),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.grey[900],
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        cardColor: Colors.grey[850],
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[800],
          border: OutlineInputBorder(),
        ),
      ),
      home: BluetoothPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BluetoothPage extends StatefulWidget {
  @override
  _BluetoothPageState createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  bool _bluetoothEnabled = false;
  bool _isConnecting = false;
  BluetoothConnection? _connection;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _connectedDevice;
  String _receivedData = "";
  final TextEditingController _messageController = TextEditingController();
  String _connectionStatus = "Desconectado";
  int _rpmValue = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initializeBluetooth();
  }

  Future<void> _requestPermissions() async {
    await Permission.location.request();
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
  }

  void _initializeBluetooth() {
    _bluetooth.state.then((state) {
      setState(() => _bluetoothEnabled = state.isEnabled);
      if (state.isEnabled) _getPairedDevices();
    });

    _bluetooth.onStateChanged().listen((state) {
      setState(() => _bluetoothEnabled = state.isEnabled);
      if (state.isEnabled) {
        _getPairedDevices();
      } else {
        setState(() {
          _devices.clear();
          _connectedDevice = null;
          _connectionStatus = "Bluetooth desactivado";
        });
      }
    });
  }

  Future<void> _getPairedDevices() async {
    List<BluetoothDevice> devices = await _bluetooth.getBondedDevices();
    setState(() => _devices = devices);
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_isConnecting || _connection?.isConnected == true) return;

    setState(() {
      _isConnecting = true;
      _connectionStatus = "Conectando...";
    });

    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      setState(() {
        _connectedDevice = device;
        _isConnecting = false;
        _connectionStatus = "Conectado a ${device.name}";
      });

      _setupDataListener();
    } catch (e) {
      setState(() {
        _connectionStatus = "Error de conexión: ${e.toString()}";
        _isConnecting = false;
      });
    }
  }

  void _setupDataListener() {
    _connection?.input
        ?.listen((data) {
          String incomingData = String.fromCharCodes(data);
          setState(() {
            _receivedData += incomingData;

            final match = RegExp(r'RPM[:\-]?\s*(\d+)').firstMatch(incomingData);
            if (match != null) {
              _rpmValue = int.tryParse(match.group(1) ?? '0') ?? 0;
            }
          });
        })
        .onDone(() {
          _disconnect();
        });
  }

  void _disconnect() {
    _connection?.dispose();
    setState(() {
      _connectedDevice = null;
      _connectionStatus = "Desconectado";
      _receivedData = "";
      _rpmValue = 0;
    });
  }

  void _sendData(String data) {
    if (_connection?.isConnected == true) {
      _connection?.output.add(Uint8List.fromList(ascii.encode("$data\n")));
      _connection?.output.allSent.then((_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Enviado: $data")));
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("No hay conexión activa")));
    }
  }

  void _toggleBluetooth(bool enabled) async {
    if (enabled) {
      await _bluetooth.requestEnable();
    } else {
      await _bluetooth.requestDisable();
    }
  }

  @override
  void dispose() {
    _connection?.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Control Bluetooth"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _getPairedDevices,
            tooltip: "Actualizar dispositivos",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildBluetoothControl(),
            _buildConnectionInfo(),
            _buildDevicesList(),
            _buildMessageInput(),
            _buildReceivedData(),
            _buildRPMGauge(),
            _buildControlButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothControl() {
    return Card(
      child: SwitchListTile(
        value: _bluetoothEnabled,
        onChanged: _toggleBluetooth,
        title: Text("Estado Bluetooth"),
        subtitle: Text(_bluetoothEnabled ? "Activado" : "Desactivado"),
      ),
    );
  }

  Widget _buildConnectionInfo() {
    return Card(
      child: ListTile(
        title: Text("Estado: $_connectionStatus"),
        subtitle:
            _connectedDevice != null
                ? Text("Dispositivo: ${_connectedDevice!.name}")
                : null,
        trailing:
            _connectedDevice != null
                ? ElevatedButton(
                  onPressed: _disconnect,
                  child: Text("Desconectar"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                )
                : null,
      ),
    );
  }

  Widget _buildDevicesList() {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              "Dispositivos Emparejados",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (_isConnecting)
            Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          if (_devices.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text("No hay dispositivos emparejados"),
            ),
          ..._devices.map(
            (device) => ListTile(
              title: Text(device.name ?? device.address),
              trailing: ElevatedButton(
                onPressed: () => _connectToDevice(device),
                child: Text("Conectar"),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
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
                  _sendData(_messageController.text);
                  _messageController.clear();
                }
              },
              child: Text("Enviar Mensaje"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceivedData() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Datos Recibidos",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(5),
              ),
              height: 100,
              child: SingleChildScrollView(
                child: Text(
                  _receivedData.isEmpty
                      ? "No hay datos recibidos"
                      : _receivedData,
                ),
              ),
            ),
            if (_receivedData.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _receivedData = ""),
                child: Text("Limpiar"),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRPMGauge() {
    double percent = (_rpmValue.clamp(0, 6000) / 6000);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "RPM: $_rpmValue",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            LinearProgressIndicator(
              value: percent,
              minHeight: 16,
              backgroundColor: Colors.grey[300],
              color: percent > 0.75 ? Colors.red : Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Controles",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _sendData("LED_ON"),
                    child: Text("Encender LED"),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _sendData("LED_OFF"),
                    child: Text(
                      "Apagar LED",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
