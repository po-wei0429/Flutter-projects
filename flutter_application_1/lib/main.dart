// 對應 Spring Boot 的 API 的 Flutter 框架整合
// 假設你的 baseUrl 是 http://10.0.2.2:8080（VSCode + Android 模擬器）

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
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
      home: TerminalStylePlantUI(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TerminalStylePlantUI extends StatefulWidget {
  @override
  _TerminalStylePlantUIState createState() => _TerminalStylePlantUIState();
}

class _TerminalStylePlantUIState extends State<TerminalStylePlantUI> {
  String _statusText = '>> 等待命令...';
  String _asciiArt = '';
  List<dynamic> _plants = [];
  int? _selectedPlantId;

  // 用於測試的 userId
  final int _userId = 1;

  // 新增可種植植物種類清單
  final List<String> _plantTypes = ['weed'];
  String? _selectedPlantType;

  String _city = '';
  String _weather = '';

  @override
  void initState() {
    super.initState();
    _fetchUserCityWeather();
    // 不自動載入植物，讓使用者主動操作
  }

  Future<void> _fetchUserCityWeather() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _statusText = '>> 無法取得定位權限';
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _statusText = '>> 定位權限被永久拒絕';
        });
        return;
      }

      // 取得目前位置
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final url = Uri.parse('$baseUrl/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userName': '測試用戶',
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _city = data['city']?.toString() ?? '';
          _weather = data['weather']?.toString() ?? '';
        });
      }
    } catch (e, stack) {
      print('定位權限錯誤: $e');
      print(stack);
      setState(() {
        _statusText = '>> 取得定位權限時發生錯誤: $e';
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
      final url = Uri.parse('$baseUrl/$_userId/plants');
      print('[DEBUG] GET: ' + url.toString());
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      print('[DEBUG] status: ' + response.statusCode.toString());
      print('[DEBUG] response: ' + response.body);
      if (response.statusCode == 200) {
        final List<dynamic> plants = jsonDecode(response.body);
        setState(() {
          _plants = plants;
          _statusText = '>> 選擇我的植物';
        });
      } else {
        setState(() {
          _statusText = '>> 無法取得植物清單 (狀態碼 ${response.statusCode})';
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
      final url = Uri.parse('$baseUrl/plant-image/$plantId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _asciiArt = response.body;
          _selectedPlantId = plantId;
        });
      } else {
        // 圖片載入失敗時，根據植物種類/生長階段顯示對應 ASCII Art
        final plant = _plants.firstWhere(
          (p) => p['id'] == plantId,
          orElse: () => null,
        );
        if (plant == null) {
          setState(() {
            _asciiArt = '>> 找不到植物資料 (id=$plantId)';
            _selectedPlantId = plantId;
          });
        } else {
          String ascii = '';
          if (plant['type'] == 'Weed') {
            ascii = getWeedAsciiArt(plant['growthStage']);
          } else if (plant['type'] == 'yourOtherType') {
            // 這裡可擴充其他植物種類的 ASCII Art
            // ascii = getOtherTypeAsciiArt(plant['growthStage']);
          } else {
            ascii = '>> 無對應的 ASCII Art';
          }
          setState(() {
            _asciiArt = ascii;
            _selectedPlantId = plantId;
          });
        }
      }
    } catch (e) {
      setState(() {
        _asciiArt = '>> 圖片載入錯誤：$e';
      });
    }
  }

  // 根據雜草生長階段產生指定 ASCII Art
  String getWeedAsciiArt(int growthStage) {
    if (growthStage == -1) {
      return '''







             :J7
            MMDbr
          .7i..dB.
       .. s     gu
     iMB7.7. 
     PQR  .:
    PBQu  rY.
 :r::    E:
          .Z..
 .|======================|.
 .|MMMMMMMMMMMMMMMMMMMMMM|.
  .\\MMMMMMMMMMMMMMMMMMMM/.
   .\\MMMMMMMMMMMMMMMMMM/.
    .\\MMMMMMMMMMMMMMMM/.
''';
    } else if (growthStage == 0) {
      return '''









                  
                  
                  
                  
                                  
            
                 
 .|===========O==========|.
 .|MMMMMMMMMMMMMMMMMMMMMM|.
  .\\MMMMMMMMMMMMMMMMMMMM/.
   .\\MMMMMMMMMMMMMMMMMM/.
    .\\MMMMMMMMMMMMMMMM/.
''';
    } else if (growthStage == 1) {
      return '''









                ,T;
              ;6gg.
              8#5:
              o;
              c.
             .@
           ;U@@j;,
 .|======================|.
 .|MMMMMMMMMMMMMMMMMMMMMM|.
  .\\MMMMMMMMMMMMMMMMMMMM/.
   .\\MMMMMMMMMMMMMMMMMM/.
    .\\MMMMMMMMMMMMMMMM/.
''';
    } else if (growthStage == 2) {
      return '''




                  .
               H@@:
             ;@@@U
             U@\$c
              T
    ,vvL;:    v  .LpW@@D:
    ;D@@@@@@J 3,@@@@@@R.
       .c5H\$#J@@@@8o,
             j@
             @T
             @v
             @o
             @o
 .|======================|.
 .|MMMMMMMMMMMMMMMMMMMMMM|.
  .\\MMMMMMMMMMMMMMMMMMMM/.
   .\\MMMMMMMMMMMMMMMMMM/.
    .\\MMMMMMMMMMMMMMMM/.
''';
    } else if (growthStage == 3) {
      return '''


                 .v;
               ,@@@,
               \$@Z
       .       c
       ,\$@@@O  ; .v5W8Z:
          L#@@;D@@@@@H,
    H@@#Z;    @J;.
     5@@@@@W  8    :;JLT;
      .o\$@@@8B; W@@@@@@@T
         :;JK@v@@@@@Wj. 
             @c.:..
             @
             @
             @;
 .|======================|.
 .|MMMMMMMMMMMMMMMMMMMMMM|.
  .\\MMMMMMMMMMMMMMMMMMMM/.
   .\\MMMMMMMMMMMMMMMMMM/.
    .\\MMMMMMMMMMMMMMMM/.
''';
    } else {
      return '';
    }
  }

  Widget _terminalButton(String label, String action) {
    return TextButton(
      onPressed: () {
        if (action == 'plant') {
          _showPlantTypeDialog();
        } else {
          _executeCommand(action);
        }
      },
      child: Text('| $label |'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.greenAccent,
        textStyle: TextStyle(fontFamily: 'monospace', fontSize: 18),
      ),
    );
  }

  Widget _asciiArtOrGifWidget() {
    if (_plants.isNotEmpty && _selectedPlantId != null) {
      final plant = _plants.firstWhere(
        (p) => p['id'] == _selectedPlantId,
        orElse: () => null,
      );
      if (plant != null && plant['growthStage'] == -1) {
        // 死亡狀態顯示 GIF
        return Image.asset(
          'assets/rick-roll.gif',
          width: 360,
          height: 220,
          fit: BoxFit.cover,
        );
      }
    }
    // 其餘狀態顯示 ASCII Art
    return Text(
      _asciiArt,
      style: TextStyle(
        fontFamily: 'monospace',
        color: Colors.greenAccent,
        fontSize: 18,
        height: 1.0,
        letterSpacing: 1.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              '[ 賽博植物終端機 v2.0 ]\n\n  種植狀態：?\n  使用者 ID：測試用戶' +
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '| 我的植物 >',
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
                minWidth: 37 * 10.0, // 36字 * 字體寬度
                maxWidth: 37 * 10.0,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _asciiArtOrGifWidget(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
