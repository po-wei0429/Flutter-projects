// 對應 Spring Boot 的 API 的 Flutter 框架整合
// 假設你的 baseUrl 是 http://10.0.2.2:8080（VSCode + Android 模擬器）

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';

const String baseUrl = 'http://10.0.2.2:8080/api/app';

void main() {
  runApp(CyberTerminalGarden());
}

class CyberTerminalGarden extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cyber Terminal Garden',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        textTheme: TextTheme(
          bodyLarge: TextStyle(
            color: Colors.greenAccent,
            fontFamily: 'monospace',
            fontSize: 16,
          ),
        ),
      ),
      home: LoginRegisterScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LoginRegisterScreen extends StatefulWidget {
  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  final TextEditingController _userNameController = TextEditingController();
  String _status = '';
  bool _isLoading = false;
  double? _latitude;
  double? _longitude;

  Future<void> _getLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _status = '無法取得定位權限';
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _status = '定位權限被永久拒絕';
        });
        return;
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      setState(() {
        _status = '取得定位失敗: $e';
      });
    }
  }

  Future<void> _register() async {
    setState(() { _isLoading = true; _status = ''; });
    final userName = _userNameController.text.trim();
    if (userName.isEmpty) {
      setState(() { _status = '請輸入用戶名稱'; _isLoading = false; });
      return;
    }
    try {
      final url = Uri.parse('$baseUrl/register');
      final resp = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'userName': userName}));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() { _status = data['message'] ?? '註冊成功'; });
      } else {
        setState(() { _status = '註冊失敗: ${resp.body}'; });
      }
    } catch (e) {
      setState(() { _status = '註冊錯誤: $e'; });
    }
    setState(() { _isLoading = false; });
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _status = '';
    });

    final userName = _userNameController.text.trim();
    if (userName.isEmpty) {
      setState(() {
        _status = '請輸入用戶名稱';
        _isLoading = false;
      });
      return;
    }

    try {
      // 取得定位（合併進登入流程）
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final url = Uri.parse('$baseUrl/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userName': userName,
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['userId'] != -1) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => TerminalStylePlantUI(
                userId: data['userId'],
                city: data['city']?.toString() ?? '',
                weather: data['weather']?.toString() ?? '',
              ),
            ),
          );
        } else {
          setState(() {
            _status = '登入失敗: ${data['message'] ?? response.body}';
          });
        }
      } else {
        setState(() {
          _status = '登入失敗: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _status = '登入錯誤: $e';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: 400,
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.greenAccent),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('賽博植物終端機', style: TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 24)),
              SizedBox(height: 24),
              TextField(
                controller: _userNameController,
                style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: '用戶名稱',
                  labelStyle: TextStyle(color: Colors.greenAccent),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                    child: Text('註冊'),
                  ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                    child: Text('登入'),
                  ),
                ],
              ),
              SizedBox(height: 24),
              if (_status.isNotEmpty)
                Text(_status, style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')),
            ],
          ),
        ),
      ),
    );
  }
}

class TerminalStylePlantUI extends StatefulWidget {
  final int userId;
  final String city;
  final String weather;

  const TerminalStylePlantUI({
    Key? key,
    required this.userId,
    required this.city,
    required this.weather,
  }) : super(key: key);

  @override
  State<TerminalStylePlantUI> createState() => _TerminalStylePlantUIState();
}

class _TerminalStylePlantUIState extends State<TerminalStylePlantUI> {
  String _statusText = '>> 等待命令...';
  List<String> _asciiArt = [];
  List<dynamic> _plants = [];
  int? _selectedPlantId;

  late final int _userId;
  late int _currentGardenUserId; // 目前瀏覽的植物園 userId

  // 好友清單
  List<Map<String, dynamic>> _friends = [];

  // 新增可種植植物種類清單
  final List<String> _plantTypes = ['weed'];
  String? _selectedPlantType;

  late String _city;
  late String _weather;

  @override
  void initState() {
    super.initState();
    _userId = widget.userId;
    _currentGardenUserId = _userId;
    _city = widget.city;
    _weather = widget.weather;
    _fetchFriends();
    // 不自動載入植物，讓使用者主動操作
  }

  Future<void> _fetchFriends() async {
    try {
      final url = Uri.parse('$baseUrl/$_userId/friends');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> friends = jsonDecode(response.body);
        setState(() {
          _friends =
              friends
                  .map((f) => {'id': f['id'], 'friendName': f['friendName']})
                  .toList();
        });
      } else {
        setState(() {
          _friends = [];
        });
      }
    } catch (e) {
      setState(() {
        _friends = [];
      });
    }
  }

  void _showPlantTypeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String tempType = _plantTypes.first;
        String tempName = '';
        return AlertDialog(
          backgroundColor: Colors.black,
          title: Text(
            '選擇植物種類並命名',
            style: TextStyle(
              color: Colors.greenAccent,
              fontFamily: 'monospace',
            ),
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: tempType,
                    dropdownColor: Colors.black,
                    iconEnabledColor: Colors.greenAccent,
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                    ),
                    items:
                        _plantTypes
                            .map(
                              (type) => DropdownMenuItem<String>(
                                value: type,
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    color: Colors.greenAccent,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (type) {
                      setState(() {
                        tempType = type!;
                      });
                    },
                  ),
                  SizedBox(height: 12),
                  TextField(
                    onChanged: (val) {
                      tempName = val;
                    },
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      labelText: '植物命名 (可選)',
                      labelStyle: TextStyle(color: Colors.greenAccent),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.greenAccent),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.greenAccent),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                '取消',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                setState(() {
                  _selectedPlantType = tempType;
                });
                Navigator.of(context).pop();
                int beforeCount = _plants.length;
                await _executeCommand('plant');
                await _showMyPlants();
                // 執行完入土後，若有命名則呼叫改名API
                if (tempName.trim().isNotEmpty && _plants.isNotEmpty) {
                  final newList = _plants;
                  int newPlantId;
                  if (newList.length > beforeCount) {
                    final oldIds =
                        _plants.take(beforeCount).map((p) => p['id']).toSet();
                    newPlantId =
                        newList.firstWhere(
                          (p) => !oldIds.contains(p['id']),
                          orElse: () => newList.last,
                        )['id'];
                  } else {
                    newPlantId = newList.last['id'];
                  }
                  await _renamePlant(newPlantId, tempName.trim());
                  setState(() {
                    _selectedPlantId = newPlantId;
                  });
                  await _showMyPlants();
                  await _loadAscii(newPlantId);
                }
              },
              child: Text(
                '確定',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _renamePlant(int plantId, String newName) async {
    try {
      final url = Uri.parse('$baseUrl/$_userId/$plantId/rename');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'newName': newName}),
      );
      print('[DEBUG] RENAME status: ' + response.statusCode.toString());
      print('[DEBUG] RENAME response: ' + response.body);
      setState(() {
        _statusText =
            (response.statusCode == 200)
                ? '>> 命名成功'
                : '>> 命名失敗 (狀態碼 ${response.statusCode})';
      });
    } catch (e) {
      setState(() {
        _statusText = '>> 命名錯誤: $e';
      });
    }
  }

  Future<void> _executeCommand(String action) async {
    try {
      // 若是 water 或 fertilize，且植物死亡則不執行
      if ((action == 'water' || action == 'fertilize') &&
          _selectedPlantId != null) {
        final plant = _plants.firstWhere(
          (p) => p['id'] == _selectedPlantId,
          orElse: () => null,
        );
        if (plant != null && plant['growthStage'] == -1) {
          setState(() {
            _statusText = '>> 植物已死亡，無法執行此操作';
          });
          return;
        }
      }
      Uri url;
      Map<String, dynamic> body = {};
      if (action == 'plant') {
        url = Uri.parse('$baseUrl/$_userId/plant');
        body = {'plantType': _selectedPlantType ?? 'weed'};
      } else if (action == 'water' && _selectedPlantId != null) {
        url = Uri.parse('$baseUrl/$_userId/${_selectedPlantId}/water');
      } else if (action == 'fertilize' && _selectedPlantId != null) {
        url = Uri.parse('$baseUrl/$_userId/${_selectedPlantId}/fertilize');
      } else {
        setState(() {
          _statusText = '>> 請先選擇植物';
        });
        return;
      }
      print('[DEBUG] POST: ' + url.toString());
      if (body.isNotEmpty) print('[DEBUG] body: ' + jsonEncode(body));
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body.isNotEmpty ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 20));
      print('[DEBUG] status: ' + response.statusCode.toString());
      print('[DEBUG] response: ' + response.body);
      setState(() {
        _statusText =
            (response.statusCode == 200)
                ? '>> 執行指令 "$action" 成功'
                : '>> 指令 "$action" 失敗 (狀態碼 ${response.statusCode})';
      });
      // 自動更新植物狀態
      if (action == 'water' || action == 'fertilize' || action == 'plant') {
        await _showMyPlants();
        if (_selectedPlantId != null) {
          await _loadAscii(_selectedPlantId!);
        }
      }
    } on TimeoutException {
      setState(() {
        _statusText = '>> 執行指令逾時，請檢查後端 API 是否啟動';
      });
    } catch (e) {
      setState(() {
        _statusText = '>> 執行錯誤: $e';
      });
    }
  }

  Future<void> _showMyPlants() async {
    try {
      final url = Uri.parse('$baseUrl/$_currentGardenUserId/plants');
      print('[DEBUG] GET: ' + url.toString());
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      print('[DEBUG] status: ' + response.statusCode.toString());
      print('[DEBUG] response: ' + response.body);
      if (response.statusCode == 200) {
        final List<dynamic> plants = jsonDecode(response.body);
        setState(() {
          _plants = plants;
          _statusText =
              _currentGardenUserId == _userId ? '>> 選擇我的植物' : '>> 查看好友植物園';
        });
      } else {
        setState(() {
          _statusText = '>> 無法取得植物清單 (狀態碼 {response.statusCode})';
        });
      }
    } on TimeoutException {
      setState(() {
        _statusText = '>> 取得植物清單逾時，請檢查後端 API 是否啟動';
      });
    } catch (e) {
      setState(() {
        _statusText = '>> 發生錯誤：$e';
      });
    }
  }

  Future<void> _loadAscii(int plantId) async {
    try {
      final plant = _plants.firstWhere(
        (p) => p['id'] == plantId,
        orElse: () => null,
      );

      if (plant == null) {
        setState(() {
          _asciiArt = ['>> 找不到植物資料 (id=$plantId)'];
          _selectedPlantId = plantId;
        });
        return;
      }

      List<String> ascii = [];
      if (plant['type'] == 'Weed') {
        ascii = getWeedAsciiArt(plant['growthStage']);
      } else {
        ascii = ['>> 無對應的 ASCII Art'];
      }

      setState(() {
        _asciiArt = ascii;
        _selectedPlantId = plantId;
      });
    } catch (e) {
      setState(() {
        _asciiArt = ['>> 載入 ASCII 錯誤: $e'];
      });
    }
  }


  // 根據雜草生長階段產生指定 ASCII Art
  List<String> getWeedAsciiArt(int growthStage) {
    if (growthStage == -1) {
      return [
"                                ",
"                                ",
"                                ",
"                                ",
"                                ",
"                                ",
"                                ",
"               :J7              ",
"                MMDbr           ",
"              .7i..dB.          ",
"           .. s     gu          ",
"         iMB7.7.                ",
"         PQR  .:                ",
"        PBQu  rY.               ",
"       :r::    E:               ",
"              .Z..              ",
"   .|======================|.   ",
"   .|MMMMMMMMMMMMMMMMMMMMMM|.   ",
"   .\\MMMMMMMMMMMMMMMMMMMMMM/.   ",
"    .\\MMMMMMMMMMMMMMMMMMMM/.    ",
"     .\\MMMMMMMMMMMMMMMMMM/.     ",
];
    } else if (growthStage == 0) {
      return [
"                                ",
"                                ",
"                                ",
"                                ",
"                                ",
"                                ",
"                                ",
"                                ",
"                                ",
"                                ",
"                                ",
"                                ",
"                                ",
"                                ",
"                                ",        
"                                ",
"   .|===========O==========|.   ",
"   .|MMMMMMMMMMMMMMMMMMMMMM|.   ",
"   .\\MMMMMMMMMMMMMMMMMMMMMM/.   ",
"    .\\MMMMMMMMMMMMMMMMMMMM/.    ",
"     .\\MMMMMMMMMMMMMMMMMM/.     ",
];
    } else if (growthStage == 1) {
      return [
"                                ",
"                                ",
"                                ",
"                                ",
"                                ",
"                                ",
"                                ",
"                                ",
"                                ",
"                  ,T;           ",
"                ;6gg.           ",
"                8#5:            ",
"                o;              ",
"                c.              ",
"               .@               ",
"             ;U@@j;,            ",
"   .|======================|.   ",
"   .|MMMMMMMMMMMMMMMMMMMMMM|.   ",
"   .\\MMMMMMMMMMMMMMMMMMMMMM/.   ",
"    .\\MMMMMMMMMMMMMMMMMMMM/.    ",
"     .\\MMMMMMMMMMMMMMMMMM/.     ",
];
    } else if (growthStage == 2) {
      return [
"                                ",
"                                ",
"                                ",
"                                ",
"                    .           ",
"                 H@@:           ",
"               ;@@@U            ",
"               U@\$c            ",
"                T               ",
"      ,vvL;:    v  .LpW@@D:     ",
"      ;D@@@@@@J 3,@@@@@@R.      ",
"         .c5H\$#J@@@@8o,        ",
"               j@               ",
"               @T               ",
"               @v               ",
"               @o               ",
"               @o               ",
"   .|======================|.   ",
"   .|MMMMMMMMMMMMMMMMMMMMMM|.   ",
"   .\\MMMMMMMMMMMMMMMMMMMMMM/.   ",
"    .\\MMMMMMMMMMMMMMMMMMMM/.    ",
"     .\\MMMMMMMMMMMMMMMMMM/.     ",
];
    } else if (growthStage == 3) {
      return [
"                                ",
"                                ",
"                  .v;           ",
"                 ,@@@,          ",
"         .       c              ",
"         ,\$@@@O  ; .v5W8Z:     ",
"            L#@@;D@@@@@H,       ",
"      H@@#Z;    @J;.            ",
"       5@@@@@W  8    :;JLT;     ",
"        .o\$@@@8B; W@@@@@@@T    ",
"           :;JK@v@@@@@Wj.       ",
"               @c.:..           ",
"               @                ",
"               @                ",
"               @;               ",
"   .|======================|.   ",
"   .|MMMMMMMMMMMMMMMMMMMMMM|.   ",
"   .\\MMMMMMMMMMMMMMMMMMMMMM/.   ",
"    .\\MMMMMMMMMMMMMMMMMMMM/.    ",
"     .\\MMMMMMMMMMMMMMMMMM/.     ",
];
    } else {
      return [""];
    }
  }

  Widget _terminalButton(String label, String action) {
    final isMyGarden = _currentGardenUserId == _userId;
    final isInteract = action == 'friend-action';
    final enabled = isMyGarden || isInteract;
    return TextButton(
      onPressed:
          enabled
              ? () {
                if (action == 'plant') {
                  if (isMyGarden) _showPlantTypeDialog();
                } else if (action == 'friend-action') {
                  _interactWithPlant();
                } else {
                  if (isMyGarden) _executeCommand(action);
                }
              }
              : null,
      child: Text('|$label|'),
      style: TextButton.styleFrom(
        foregroundColor: enabled ? Colors.greenAccent : Colors.grey,
        textStyle: TextStyle(fontFamily: 'monospace', fontSize: 18),
      ),
    );
  }

  // 互動功能：將當前植物畫面倒過來顯示，並切換 pot 狀態
  Future<void> _interactWithPlant() async {
    if (_selectedPlantId == null) {
      setState(() {
        _statusText = '>> 請先選擇植物';
      });
      return;
    }
    try {
      // 查詢目前植物狀態
      final url = Uri.parse('$baseUrl/$_currentGardenUserId/plants');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> plants = jsonDecode(response.body);
        final plant = plants.firstWhere(
          (p) => p['id'] == _selectedPlantId,
          orElse: () => null,
        );
        if (plant == null) {
          setState(() {
            _statusText = '>> 找不到植物';
          });
          return;
        }
        final postUrl = Uri.parse(
          '$baseUrl/$_userId/friend-action/$_selectedPlantId',
        );
        final postResp = await http.post(
          postUrl,
          headers: {'Content-Type': 'application/json'},
        );
        if (postResp.statusCode == 200) {
          setState(() {
            _statusText = '>> 互動成功，pot 狀態已切換';
          });
          await _showMyPlants();
          await _loadAscii(_selectedPlantId!);
        } else {
          setState(() {
            _statusText = '>> 互動失敗 (狀態碼 ${postResp.statusCode})';
          });
        }
      } else {
        setState(() {
          _statusText = '>> 取得植物狀態失敗 (狀態碼 ${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _statusText = '>> 互動錯誤: $e';
      });
    }
  }

  Widget _asciiArtOrGifWidget() {
    Widget asciiColumn(List<String> lines) {
      return SizedBox(
        width: 380,
        height: 450,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: lines.map((line) => SelectableText(
            line,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 18,
              color: Colors.greenAccent,
              height: 1.0,
              letterSpacing: 1.0,
            ),
          )).toList(),
        ),
      );
    }

    if (_plants.isNotEmpty && _selectedPlantId != null) {
      final plant = _plants.firstWhere(
        (p) => p['id'] == _selectedPlantId,
        orElse: () => null,
      );

      // pot = Change 時反轉
      if (plant != null && plant['pot'] != 'Original') {
        final reversed = _asciiArt.reversed.toList();
        return asciiColumn(reversed);
      }

      // 雨天效果
      if (_weather.toLowerCase().contains('rain')) {
        return SizedBox(
          width: 370,
          height: 450,
          child: RainAsciiOverlay(asciiArt: _asciiArt),
        );
      }

      // 多雲
      if (_weather.toLowerCase().contains('cloud')) {
        return CloudAsciiOverlay(asciiArt: _asciiArt);
      }

    }

    return asciiColumn(_asciiArt);
  }


  @override
  Widget build(BuildContext context) {
    final isMyGarden = _currentGardenUserId == _userId;
    return Scaffold(
      appBar: AppBar(
        title: Text('Cyber Terminal Garden'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.greenAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '[ 賽博植物終端機 v2.0 ]\n目前瀏覽：' +
                  (isMyGarden
                      ? '自己的植物園'
                      : '好友(${_friends.firstWhere((f) => f['id'] == _currentGardenUserId, orElse: () => {'friendName': '未知'})['friendName']})的植物園') +
                  (_city.isNotEmpty || _weather.isNotEmpty
                      ? '\n  城市：$_city\n  天氣：$_weather'
                      : ''),
              style: TextStyle(
                fontFamily: 'monospace',
                color: Colors.greenAccent,
                fontSize: 16,
              ),
            ),

            Wrap(
              spacing: 0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _terminalButton('入土', 'plant'),
                _terminalButton('澆水', 'water'),
                _terminalButton('施肥', 'fertilize'),
                _terminalButton('互動', 'friend-action'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.0),
                  child: Text(
                    ' |植物 > ',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 18,
                    ),
                  ),
                ),
                DropdownButton<int>(
                  value:
                      (_selectedPlantId != null &&
                              _plants.isNotEmpty &&
                              _plants.any((p) => p['id'] == _selectedPlantId))
                          ? _selectedPlantId
                          : null,
                  hint: Text(
                    _plants.isEmpty ? '尚無植物，點擊刷新' : '選擇我的植物',
                    style: TextStyle(color: Colors.greenAccent),
                  ),
                  dropdownColor: Colors.black,
                  iconEnabledColor: Colors.greenAccent,
                  items:
                      _plants.isEmpty
                          ? [
                            DropdownMenuItem<int>(
                              value: null,
                              child: Text(
                                '（無資料）',
                                style: TextStyle(color: Colors.greenAccent),
                              ),
                            ),
                          ]
                          : _plants.map<DropdownMenuItem<int>>((plant) {
                            final displayName =
                                (plant['name'] != null &&
                                        plant['name']
                                            .toString()
                                            .trim()
                                            .isNotEmpty &&
                                        plant['name']
                                                .toString()
                                                .trim()
                                                .toUpperCase() !=
                                            'NULL')
                                    ? plant['name']
                                    : '未命名';
                            return DropdownMenuItem<int>(
                              value: plant['id'],
                              child: Text(
                                '$displayName（${plant['type']} / 階段：${plant['growthStage']}）',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          }).toList(),
                  onChanged: (int? plantId) {
                    if (plantId != null) _loadAscii(plantId);
                  },
                  onTap: _showMyPlants, // 點擊下拉選單時才刷新
                ),
                // 新增：好友植物園下拉選單
                Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: DropdownButton<int>(
                    value:
                        _currentGardenUserId == _userId
                            ? null
                            : _currentGardenUserId,
                    hint: Text(
                      '進入好友植物園',
                      style: TextStyle(color: Colors.greenAccent),
                    ),
                    dropdownColor: Colors.black,
                    iconEnabledColor: Colors.greenAccent,
                    items: [
                      DropdownMenuItem<int>(
                        value: null,
                        child: Text(
                          '自己',
                          style: TextStyle(color: Colors.greenAccent),
                        ),
                      ),
                      ..._friends.map(
                        (f) => DropdownMenuItem<int>(
                          value: f['id'],
                          child: Text(
                            f['friendName'],
                            style: TextStyle(color: Colors.greenAccent),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (int? friendId) async {
                      setState(() {
                        _currentGardenUserId = friendId ?? _userId;
                        _selectedPlantId = null;
                        _asciiArt = [];
                        _statusText =
                            friendId == null
                                ? '>> 已回到自己的植物園'
                                : '>> 已進入"' +
                                    (_friends.firstWhere(
                                      (f) => f['id'] == friendId,
                                      orElse: () => {'friendName': '未知'},
                                    )['friendName']) +
                                    '"的植物園';
                      });
                      await _showMyPlants();
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: _currentGardenUserId == _userId ? () async {
                    final response = await http.get(Uri.parse('$baseUrl/$_userId/search-users'));
                    final List<dynamic> searchResults = jsonDecode(response.body);

                    if (searchResults.isEmpty) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text("沒有找到使用者"),
                          content: Text("附近沒有其他使用者"),
                          actions: [
                            TextButton(
                              child: Text("關閉"),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      );
                      return;
                    }

                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          backgroundColor: Colors.black,
                          title: Text(
                            "搜尋結果",
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontFamily: 'monospace',
                            ),
                          ),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: searchResults.length,
                              itemBuilder: (context, index) {
                                final user = searchResults[index];
                                return ListTile(
                                  title: Text(
                                    user['userName'],
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  subtitle: Text(
                                    'ID: ${user['id']}',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  trailing: TextButton(
                                    child: Text(
                                      "加入",
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: Text(
                                              "確認加入",
                                              style: TextStyle(
                                              color: Colors.greenAccent,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                          content: Text(
                                              "確定要加入 ${user['userName']} 為好友嗎？",
                                              style: TextStyle(
                                              color: Colors.greenAccent,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              child: Text(
                                                  "取消",style: TextStyle(
                                                  color: Colors.greenAccent,
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                              onPressed: () => Navigator.pop(context, false),
                                            ),
                                            TextButton(
                                              child: Text(
                                                "是",
                                                style: TextStyle(
                                                  color: Colors.greenAccent,
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                              onPressed: () => Navigator.pop(context, true),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true) {
                                        final addResp = await http.post(
                                          Uri.parse('$baseUrl/$_userId/add-friend'),
                                          headers: {'Content-Type': 'application/json'},
                                          body: jsonEncode({'friendName': user['userName']}),
                                        );
                                        final msg = addResp.body;
                                        Navigator.pop(context); // 關閉搜尋清單視窗
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(msg)),
                                        );
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  } : null,
                  child: Text("| 搜尋好友 |"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.greenAccent,
                    textStyle: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  )
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              alignment: Alignment.topLeft,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent),
              ),
              child: Text(
                _statusText,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.greenAccent,
                ),
              ),
            ),
            // 新增 ASCII Art 顯示區塊
            const SizedBox(height: 10),
            Container(
              alignment: Alignment.topLeft,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent),
              ),
              constraints: BoxConstraints(
                minHeight: 450, // 22行 * 字體高度
                maxHeight: 450,
                minWidth: 380, // 36字 * 字體寬度
                maxWidth: 380,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: _asciiArtOrGifWidget(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RainAsciiOverlay extends StatefulWidget {
  final List<String> asciiArt;

  const RainAsciiOverlay({super.key, required this.asciiArt});

  @override
  State<RainAsciiOverlay> createState() => _RainAsciiOverlayState();
}

class _RainAsciiOverlayState extends State<RainAsciiOverlay> {
  static const int numBars = 20;
  static const Duration frameDelay = Duration(milliseconds: 150);
  late List<List<String>> canvas;
  late List<Offset> barPositions;
  late Timer timer;
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    canvas = widget.asciiArt.map((line) => line.padRight(32).split('')).toList();
    barPositions = List.generate(numBars, (_) {
      int col = random.nextInt(32);
      return Offset(0, col.toDouble());
    });
    timer = Timer.periodic(frameDelay, (_) => updateFrame());
  }

  void updateFrame() {
    final frame = widget.asciiArt
        .map((line) => line.padRight(32).split(''))
        .toList(); // <-- 每次重新從原始 ASCII 畫板開始
    final List<Offset> newPositions = [];

    for (var pos in barPositions) {
      int i = pos.dy.toInt();
      int j = pos.dx.toInt();

      if (i < frame.length) {
        if (frame[i][j] == ' ') {
          frame[i][j] = '|';
          newPositions.add(Offset(j.toDouble(), (i + 1).toDouble()));
        } else {
          frame[i][j] = '*';
          newPositions.add(Offset(random.nextInt(32).toDouble(), 0));
        }
      } else {
        newPositions.add(Offset(random.nextInt(32).toDouble(), 0));
      }
    }

    setState(() {
      canvas = frame;
      barPositions = newPositions;
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(
        color: Colors.greenAccent,
        fontFamily: 'monospace',
        fontSize: 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: canvas.map((row) => Text(row.join())).toList(),
      ),
    );
  }
}

class CloudAsciiOverlay extends StatefulWidget {
  final List<String> asciiArt;
  const CloudAsciiOverlay({super.key, required this.asciiArt});

  @override
  State<CloudAsciiOverlay> createState() => _CloudAsciiOverlayState();
}

class _CloudAsciiOverlayState extends State<CloudAsciiOverlay> {
  static const int numCloud = 8;
  static const Duration frameDelay = Duration(milliseconds: 150);
  late List<List<String>> canvas;
  late List<Offset> barPositions;
  late Timer timer;
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    canvas = widget.asciiArt.map((line) => line.padRight(32).split('')).toList();

    barPositions = List.generate(numCloud, (_) {
      int row = random.nextInt(3);
      return Offset(0.0, row.toDouble());
    });

    timer = Timer.periodic(frameDelay, (_) => updateFrame());
  }

  void updateFrame() {
    final frame = widget.asciiArt
        .map((line) => line.padRight(32).split(''))
        .toList(); // <-- 每次重新從原始 ASCII 畫板開始
    final List<Offset> newPositions = [];

    for (var pos in barPositions) {
      int row = pos.dy.toInt();  // row 0~2
      int col = pos.dx.toInt();  // column

      if (row < frame.length && col < frame[row].length) {
        if (frame[row][col] == ' ') {
          frame[row][col] = '~'; // 或 '☁'
          newPositions.add(Offset(col + 1.0, row.toDouble()));
        } else {
          newPositions.add(Offset(0, random.nextInt(3).toDouble()));
        }
      } else {
        newPositions.add(Offset(0, random.nextInt(3).toDouble()));
      }
    }

    setState(() {
      canvas = frame;
      barPositions = newPositions;
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(
        color: Colors.greenAccent,
        fontFamily: 'monospace',
        fontSize: 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: canvas.map((row) => Text(row.join())).toList(),
      ),
    );
  }
}