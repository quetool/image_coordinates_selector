import 'dart:convert';
// import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(MyApp());
}

class PickerData {
  Color colorPicked;
  Offset globalPosition, localPosition;

  PickerData({this.colorPicked, this.globalPosition, this.localPosition});
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  SharedPreferences _prefs;
  var _imagePath = 'assets/europe.png';

  img.Image _pixelPhoto;

  var _dotSize = 6.0;
  var _maxScale = 6.0;
  var _minScale = 1.0;
  var _currentScale = 1.0;

  List<Widget> _stackChildren = [];
  List<String> _coordinates = [];
  var _imageKey = GlobalKey();

  var _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    rootBundle.load(_imagePath).then((ByteData byteData) {
      List<int> values = byteData.buffer.asUint8List();
      print("values");
      _pixelPhoto = img.decodeImage(values);
      print("pixelPhoto");
      SharedPreferences.getInstance().then((value) {
        _prefs = value;
        _stackChildren.add(
          Center(
            child: Image.asset(
              _imagePath,
              key: _imageKey,
            ),
          ),
        );
        _getStoredCoordinates();
      });
    });
  }

  void _getStoredCoordinates() async {
    _coordinates = _prefs.getStringList('coordinates') ?? [];
    _coordinates.forEach((coord) {
      Map<String, dynamic> pair = json.decode(coord);
      _stackChildren.add(
        Padding(
          padding: EdgeInsets.only(
            top: pair["y"],
            left: pair["x"],
          ),
          child: Container(
            width: _dotSize,
            height: _dotSize,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.7),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Container(
        height: double.infinity,
        child: InteractiveViewer(
          transformationController: _transformationController,
          maxScale: _maxScale,
          minScale: _minScale,
          onInteractionUpdate: (ScaleUpdateDetails details) {
            _currentScale = _transformationController.value.getMaxScaleOnAxis();
            if (_currentScale > _maxScale) _currentScale = _maxScale;
            if (_currentScale < _minScale) _currentScale = _minScale;
            _dotSize = _maxScale / _currentScale;
            _stackChildren.removeRange(1, _stackChildren.length - 1);
            _getStoredCoordinates();
          },
          child: GestureDetector(
            onTapUp: (TapUpDetails details) {
              print("TAP");
              _getPixelFromTapPosition(
                details.globalPosition,
                details.localPosition,
              ).then((pickerData) => _addDotToImage(pickerData));
            },
            child: Stack(
              children: this._stackChildren,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.backspace),
        onPressed: _deleteLastCoordinate,
      ),
    );
  }

  Future<PickerData> _getPixelFromTapPosition(
      Offset globalPosition, Offset dotPosition) async {
    // var byteData = await rootBundle.load(_imagePath);
    // List<int> values = _byteData.buffer.asUint8List();
    // print("values");
    // img.Image pixelPhoto = img.decodeImage(values);
    // print("pixelPhoto");
    RenderBox box = _imageKey.currentContext.findRenderObject();
    print("box");
    Offset localPosition = box.globalToLocal(globalPosition);
    print("localPosition");

    double px = localPosition.dx;
    double py = localPosition.dy;
    print("$px, $py");

    double widgetScale = box.size.width / _pixelPhoto.width;
    px = (px / widgetScale);
    py = (py / widgetScale);

    int pixelSafe = _pixelPhoto.getPixelSafe(px.toInt(), py.toInt());
    int intColor = pixelSafe.getPixelColor();

    var pickerData = PickerData()
      ..colorPicked = Color(intColor)
      ..globalPosition = globalPosition
      ..localPosition = dotPosition;
    return pickerData;
  }

  void _addDotToImage(PickerData pickerData) {
    if (pickerData.colorPicked == null) return;
    if (pickerData.colorPicked.opacity < 1.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Out of body bounds!'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      setState(() {
        _stackChildren.add(
          Padding(
            padding: EdgeInsets.only(
              top: (pickerData.localPosition.dy - (_dotSize / 2.0)),
              left: (pickerData.localPosition.dx - (_dotSize / 2.0)),
            ),
            child: Container(
              width: _dotSize,
              height: _dotSize,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      });
      _saveCoordinates(pickerData.localPosition);
    }
  }

  void _saveCoordinates(Offset localPosition) {
    var pair = json.encode({
      'x': (localPosition.dx - (_dotSize / 2.0)),
      'y': (localPosition.dy - (_dotSize / 2.0)),
    });
    _coordinates.add(pair);
    _syncLocalStorage();
  }

  void _deleteLastCoordinate() {
    if (_coordinates.isEmpty) return;
    setState(() {
      _coordinates.removeLast();
      _stackChildren.removeLast();
    });
    _syncLocalStorage();
  }

  void _syncLocalStorage() {
    _prefs.setStringList('coordinates', _coordinates);
  }
}

extension IntExtension on int {
  int getPixelColor() {
    int r = (this >> 16) & 0xFF;
    int b = this & 0xFF;
    return (this & 0xFF00FF00) | (b << 16) | r;
  }
}
