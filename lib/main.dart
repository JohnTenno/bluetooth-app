import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Controle bluetooth',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.indigo,
        colorScheme: ThemeData.dark().colorScheme.copyWith(
          secondary: Colors.indigoAccent,
          onSecondary: Colors.black,
        ),
        cardColor: Colors.grey[850],
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          color: Colors.black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),

      home: const BluetoothPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

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
  double _pedalValue = 0;
  String _receivedData = "";
  final TextEditingController _messageController = TextEditingController();
  String _connectionStatus = "Desconectado";
  int _rpmValue = 0;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _requestPermissions();
    await _initializeBluetooth();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
  }

  Future<void> _initializeBluetooth() async {
    final state = await _bluetooth.state;
    setState(() => _bluetoothEnabled = state.isEnabled);
    if (state.isEnabled) await _getPairedDevices();

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
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final devices = await _bluetooth.getBondedDevices();
      setState(() => _devices = devices);
    } finally {
      setState(() => _isRefreshing = false);
    }
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
      _showConnectionSuccess(device.name ?? device.address);
    } catch (e) {
      setState(() {
        _connectionStatus = "Error de conexión";
        _isConnecting = false;
      });
      _showConnectionError(e.toString());
    }
  }

  void _showConnectionSuccess(String deviceName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Conectado a $deviceName'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showConnectionError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error de conexión: $error'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _setupDataListener() {
    _connection?.input
        ?.listen((data) {
          final incomingData = String.fromCharCodes(data);
          setState(() {
            _receivedData += incomingData;
            _updateRpmValue(incomingData);
          });
        })
        .onDone(_disconnect);
  }

  void _updateRpmValue(String data) {
    final match = RegExp(r'RPM[:\-]?\s*(\d+)').firstMatch(data);
    if (match != null) {
      _rpmValue = int.tryParse(match.group(1) ?? '0') ?? 0;
    }
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

  Future<void> _sendData(String data) async {
    if (_connection?.isConnected != true) {
      _showNoConnectionError();
      return;
    }

    try {
      _connection?.output.add(Uint8List.fromList(ascii.encode("$data\n")));
      await _connection?.output.allSent;
      _showSendSuccess(data);
    } catch (e) {
      _showSendError(e.toString());
    }
  }

  void _showNoConnectionError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("No hay conexión activa"),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSendSuccess(String data) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Enviado: $data"), backgroundColor: Colors.green),
    );
  }

  void _showSendError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Error al enviar: $error"),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _toggleBluetooth(bool enabled) async {
    try {
      if (enabled) {
        await _bluetooth.requestEnable();
      } else {
        await _bluetooth.requestDisable();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error al ${enabled ? 'activar' : 'desactivar'} Bluetooth",
          ),
          backgroundColor: Colors.red,
        ),
      );
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
        title: const Text("Control Bluetooth"),
        actions: [
          IconButton(
            icon:
                _isRefreshing
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.refresh),
            onPressed: _getPairedDevices,
            tooltip: "Actualizar dispositivos",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildBluetoothStatusCard(),
            _buildConnectionStatusCard(),
            _buildPairedDevicesCard(),
            _buildRpmGauge(),
            _buildControlPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SwitchListTile(
          value: _bluetoothEnabled,
          onChanged: _toggleBluetooth,
          title: const Text(
            "Estado Bluetooth",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            _bluetoothEnabled ? "Activado" : "Desactivado",
            style: TextStyle(
              color: _bluetoothEnabled ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
          secondary: Icon(
            _bluetoothEnabled
                ? Icons.bluetooth_connected
                : Icons.bluetooth_disabled,
            color: _bluetoothEnabled ? Colors.indigoAccent : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Estado de conexión",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _connectedDevice != null ? Icons.link : Icons.link_off,
                  color:
                      _connectedDevice != null
                          ? Colors.greenAccent
                          : Colors.redAccent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _connectionStatus,
                        style: TextStyle(
                          color:
                              _connectedDevice != null
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                        ),
                      ),
                      if (_connectedDevice != null)
                        Text(
                          "Dispositivo: ${_connectedDevice!.name}",
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (_connectedDevice != null)
                  ElevatedButton(
                    onPressed: _disconnect,
                    child: const Text("Desconectar"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairedDevicesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Dispositivos Emparejados",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_isConnecting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_devices.isEmpty && !_isRefreshing)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    "No hay dispositivos emparejados",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ..._devices.map(
              (device) => ListTile(
                leading: const Icon(Icons.devices),
                title: Text(device.name ?? "Dispositivo desconocido"),
                subtitle: Text(device.address),
                trailing: ElevatedButton(
                  onPressed: () => _connectToDevice(device),
                  child: const Text("Conectar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRpmGauge() {
    final percent = (_rpmValue.clamp(0, 6000) / 6000);
    final color =
        percent > 0.75
            ? Colors.redAccent
            : percent > 0.5
            ? Colors.orangeAccent
            : Colors.greenAccent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "MONITOR DE RPM",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "$_rpmValue RPM",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: percent,
              minHeight: 16,
              backgroundColor: Colors.grey[800],
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [Text("0"), Text("3000"), Text("6000")],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "PANEL DE CONTROL",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            _buildPowerButtons(),
            const SizedBox(height: 24),
            _buildPedalControl(),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Control de energía",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Listener(
                onPointerDown: (_) => _sendData("TURN_ON"),
                onPointerUp: (_) => _sendData("STOP"),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.power_settings_new, size: 20),
                  label: const Text("MANTENER PARA ENCENDER"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                  ),
                  onPressed: null,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _sendData("TURN_OFF"),
                icon: const Icon(Icons.power_off, size: 20),
                label: const Text("APAGAR"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPedalControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Control de aceleración",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.indigoAccent,
            inactiveTrackColor: Colors.grey[700],
            thumbColor: Colors.indigoAccent,
            overlayColor: Colors.indigoAccent.withOpacity(0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            valueIndicatorColor: Colors.indigoAccent,
            showValueIndicator: ShowValueIndicator.always,
          ),
          child: Slider(
            value: _pedalValue,
            min: 0,
            max: 180,
            divisions: 180,
            label: "${_pedalValue.toInt()}°",
            onChanged: (value) {
              setState(() => _pedalValue = value);
              _sendData("SERVO:${_pedalValue.toInt()}");
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [Text("0"), Text("50"), Text("100")],
        ),
      ],
    );
  }
}
