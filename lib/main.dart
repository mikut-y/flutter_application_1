import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScheduleApp());
}

class ScheduleApp extends StatefulWidget {
  const ScheduleApp({super.key});

  @override
  State<ScheduleApp> createState() => _ScheduleAppState();
}

class _ScheduleAppState extends State<ScheduleApp> {
  Color currentThemeColor = const Color(0xFFF472B6);

  @override
  void initState() {
    super.initState();
    _loadThemeColor();
  }

  Future<void> _loadThemeColor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorValue = prefs.getInt('theme_color_v2');
      if (colorValue != null) {
        setState(() {
          currentThemeColor = Color(colorValue);
        });
      }
    } catch (e) {
      debugPrint('テーマ読み込みエラー: $e');
    }
  }

  Future<void> changeTheme(Color newColor) async {
    setState(() {
      currentThemeColor = newColor;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_color_v2', newColor.toARGB32());
    } catch (e) {
      debugPrint('テーマ保存エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'マイ スケジュール',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFE2E8F0),
        colorScheme: ColorScheme.fromSeed(
          seedColor: currentThemeColor,
          primary: currentThemeColor,
        ),
      ),
      home: DashboardPage(
        currentThemeColor: currentThemeColor,
        onChangeTheme: changeTheme,
      ),
    );
  }
}

enum MissionType { meter, checkbox }

class MissionItem {
  String id;
  String title;
  double startHour;
  double endHour;
  double progress;
  bool isCompleted;
  MissionType type;

  MissionItem({
    required this.id,
    required this.title,
    required this.startHour,
    required this.endHour,
    this.progress = 0.0,
    this.isCompleted = false,
    required this.type,
  });

  double get effectiveProgress {
    if (type == MissionType.checkbox) {
      return isCompleted ? 1.0 : 0.0;
    }
    return progress;
  }

  String get timeString {
    String format(double h) {
      int hour = h.floor();
      int minute = ((h - hour) * 60).round();
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }
    return '${format(startHour)}〜${format(endHour)}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startHour': startHour,
        'endHour': endHour,
        'progress': progress,
        'isCompleted': isCompleted,
        'type': type.index,
      };

  factory MissionItem.fromJson(Map<String, dynamic> json) => MissionItem(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        startHour: (json['startHour'] as num?)?.toDouble() ?? 9.0,
        endHour: (json['endHour'] as num?)?.toDouble() ?? 10.0,
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
        isCompleted: json['isCompleted'] ?? false,
        type: MissionType.values[(json['type'] as int?) ?? 0],
      );
}

class DashboardPage extends StatefulWidget {
  final Color currentThemeColor;
  final Function(Color) onChangeTheme;

  const DashboardPage({
    super.key,
    required this.currentThemeColor,
    required this.onChangeTheme,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<MissionItem> missions = [];
  String? hoveredMissionId; // マウスホバー中のミッションID

  Timer? _timer;
  int _initialSeconds = 25 * 60;
  int _remainingSeconds = 25 * 60;
  bool _isTimerRunning = false;

  bool _showEndMessage = false;

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  void _sortMissions() {
    missions.sort((a, b) => a.startHour.compareTo(b.startHour));
  }

  Future<void> _loadMissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString('saved_missions_v2');
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        setState(() {
          missions = jsonList.map((e) => MissionItem.fromJson(e)).toList();
          _sortMissions();
        });
        return;
      }
    } catch (e) {
      debugPrint('目標読み込みエラー: $e');
    }

    _setDefaultMissions();
  }

  void _setDefaultMissions() {
    setState(() {
      missions = [
        MissionItem(
          id: '1',
          title: '☕ 今日のメインタスク',
          startHour: 10.0,
          endHour: 12.0,
          progress: 0.0,
          type: MissionType.meter,
        ),
      ];
      _sortMissions();
    });
    _saveMissions();
  }

  Future<void> _saveMissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString =
          jsonEncode(missions.map((e) => e.toJson()).toList());
      await prefs.setString('saved_missions_v2', jsonString);
    } catch (e) {
      debugPrint('目標保存エラー: $e');
    }
  }

  void _startTimer() {
    if (_isTimerRunning || _remainingSeconds <= 0) return;
    setState(() => _isTimerRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
          _isTimerRunning = false;
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isTimerRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = _initialSeconds;
      _isTimerRunning = false;
    });
  }

  void _showSetTimerDialog() {
    final controller = TextEditingController(
        text: (_initialSeconds ~/ 60).toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'タイマーの時間を設定',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: widget.currentThemeColor),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '分数（分）を入力',
              hintText: '例: 25',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.currentThemeColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final int? minutes = int.tryParse(controller.text);
                if (minutes != null && minutes > 0) {
                  _timer?.cancel();
                  setState(() {
                    _initialSeconds = minutes * 60;
                    _remainingSeconds = minutes * 60;
                    _isTimerRunning = false;
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('設定'),
            ),
          ],
        );
      },
    );
  }

  String get _formattedTimerTime {
    int minutes = _remainingSeconds ~/ 60;
    int seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double get totalProgress {
    if (missions.isEmpty) return 0.0;
    double sum = missions.fold(0, (prev, item) => prev + item.effectiveProgress);
    return sum / missions.length;
  }

  TimeOfDay _doubleToTime(double hourDouble) {
    int hour = hourDouble.floor();
    int minute = ((hourDouble - hour) * 60).round();
    return TimeOfDay(hour: hour, minute: minute);
  }

  void _showMissionDialog({MissionItem? itemToEdit}) {
    final isEditing = itemToEdit != null;
    final titleController =
        TextEditingController(text: isEditing ? itemToEdit.title : '');

    TimeOfDay startTime = isEditing
        ? _doubleToTime(itemToEdit.startHour)
        : const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = isEditing
        ? _doubleToTime(itemToEdit.endHour)
        : const TimeOfDay(hour: 10, minute: 0);

    MissionType selectedType =
        isEditing ? itemToEdit.type : MissionType.meter;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                isEditing ? '目標を編集' : '新しい目標を追加',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.currentThemeColor,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: '目標の内容',
                        hintText: '例: 📚 勉強、読書など',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('時間設定:'),
                        OutlinedButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: startTime,
                              initialEntryMode: TimePickerEntryMode.dialOnly,
                            );
                            if (picked != null) {
                              setDialogState(() => startTime = picked);
                            }
                          },
                          child: Text(startTime.format(context)),
                        ),
                        const Text('〜'),
                        OutlinedButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: endTime,
                              initialEntryMode: TimePickerEntryMode.dialOnly,
                            );
                            if (picked != null) {
                              setDialogState(() => endTime = picked);
                            }
                          },
                          child: Text(endTime.format(context)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('達成度の管理方法:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        ListTile(
                          title: const Text('メーター（%で調整）'),
                          leading: Radio<MissionType>(
                            value: MissionType.meter,
                            groupValue: selectedType,
                            activeColor: widget.currentThemeColor,
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedType = val);
                              }
                            },
                          ),
                          onTap: () {
                            setDialogState(() => selectedType = MissionType.meter);
                          },
                        ),
                        ListTile(
                          title: const Text('チェックボックス（完了/未完了）'),
                          leading: Radio<MissionType>(
                            value: MissionType.checkbox,
                            groupValue: selectedType,
                            activeColor: widget.currentThemeColor,
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedType = val);
                              }
                            },
                          ),
                          onTap: () {
                            setDialogState(() => selectedType = MissionType.checkbox);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.currentThemeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (titleController.text.isEmpty) return;

                    double startH = startTime.hour + (startTime.minute / 60.0);
                    double endH = endTime.hour + (endTime.minute / 60.0);

                    if (endH <= startH) endH = startH + 1.0;

                    setState(() {
                      if (isEditing) {
                        itemToEdit.title = titleController.text;
                        itemToEdit.startHour = startH;
                        itemToEdit.endHour = endH;
                        itemToEdit.type = selectedType;
                      } else {
                        missions.add(
                          MissionItem(
                            id: DateTime.now().toString(),
                            title: titleController.text,
                            startHour: startH,
                            endHour: endH,
                            progress: 0.0,
                            type: selectedType,
                          ),
                        );
                      }
                      _sortMissions();
                    });
                    _saveMissions();
                    Navigator.pop(context);
                  },
                  child: Text(isEditing ? '保存' : '追加'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDayEnd() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('今日を終了しますか？',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('今日一日の頑張りを振り返りましょう♪'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('まだつづける', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.currentThemeColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _showEndMessage = true;
                });
                Navigator.pop(context);
              },
              child: const Text('終了する！'),
            ),
          ],
        );
      },
    );
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('全消去しますか？',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
          content: const Text('登録した目標がすべて消えます。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  missions.clear();
                  _showEndMessage = false;
                });
                _saveMissions();
                Navigator.pop(context);
              },
              child: const Text('全消去'),
            ),
          ],
        );
      },
    );
  }

  Map<String, String> _getCharacterData() {
    int percent = (totalProgress * 100).round();

    String icon = '🐰';
    String charName = 'うさぎちゃん';

    if (widget.currentThemeColor.toARGB32() == const Color(0xFF38BDF8).toARGB32()) {
      icon = '🐱';
      charName = 'ネコちゃん';
    } else if (widget.currentThemeColor.toARGB32() == const Color(0xFFC084FC).toARGB32()) {
      icon = '🦔';
      charName = 'ハリネズミくん';
    } else if (widget.currentThemeColor.toARGB32() == const Color(0xFF34D399).toARGB32()) {
      icon = '🐹';
      charName = 'ハムちゃん';
    }

    String message = '';
    if (percent <= 50) {
      message = '今日もお疲れ様！少しでも前進できたのが偉いよ♪ 明日またマイペースにがんばろ！';
    } else if (percent <= 80) {
      message = '半分以上も達成できたね！すごい！しっかり体を休めてね✨';
    } else if (percent <= 99) {
      message = 'あと一歩のところまでクリア！本当によく頑張ったね、誇っていいよ！🌸';
    } else {
      message = 'パーフェクト達成おめでとう！！完璧すぎるよ！今日は自分を思いっきり褒めてあげてね🎉';
    }

    return {'icon': icon, 'name': charName, 'message': message};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      _buildTotalProgressCard(),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > 800) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: _buildMissionList()),
                                const SizedBox(width: 24),
                                Expanded(flex: 2, child: _buildRightSideContent()),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                _buildMissionList(),
                                const SizedBox(height: 24),
                                _buildRightSideContent(),
                              ],
                            );
                          }
                        },
                      ),

                      if (_showEndMessage) ...[
                        const SizedBox(height: 30),
                        _buildThanksMessageCard(),
                      ],

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            left: 20,
            bottom: 20,
            child: _buildFloatingColorThemePicker(),
          ),

          Positioned(
            right: 20,
            bottom: 20,
            child: ElevatedButton.icon(
              onPressed: _confirmDayEnd,
              icon: const Text('✨', style: TextStyle(fontSize: 16)),
              label: const Text('一日終わり！',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.currentThemeColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingColorThemePicker() {
    final colors = [
      const Color(0xFFF472B6),
      const Color(0xFF38BDF8),
      const Color(0xFFC084FC),
      const Color(0xFF34D399),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: colors.map((color) {
          bool isSelected =
              widget.currentThemeColor.toARGB32() == color.toARGB32();
          return GestureDetector(
            onTap: () => widget.onChangeTheme(color),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: Colors.black87, width: 2.5)
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildThanksMessageCard() {
    final charData = _getCharacterData();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.currentThemeColor, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                charData['icon']!,
                style: const TextStyle(fontSize: 40),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    charData['name']!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: widget.currentThemeColor,
                    ),
                  ),
                  const Text(
                    '今日のおつかれさまメッセージ',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.currentThemeColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              charData['message']!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '✨ 本日のダッシュボード ✨',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: widget.currentThemeColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'メリハリをつけてクリアしよう〜！👑',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalProgressCard() {
    int percent = (totalProgress * 100).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📈 今日の総進捗率',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: widget.currentThemeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                width: constraints.maxWidth,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      width: constraints.maxWidth * totalProgress,
                      height: 12,
                      decoration: BoxDecoration(
                        color: widget.currentThemeColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMissionList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '📑 本日のミッション一覧',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Colors.grey.shade800,
              ),
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showMissionDialog(),
                  icon: const Text('＋', style: TextStyle(fontSize: 14, color: Colors.white)),
                  label: const Text('追加', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.currentThemeColor,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _confirmReset,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('全消去',
                      style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: missions.length,
          itemBuilder: (context, index) {
            final item = missions[index];
            final isHovered = hoveredMissionId == item.id;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: isHovered
                  ? (Matrix4.identity()..translate(0, -6, 0)) // 浮き出るアニメーション
                  : Matrix4.identity(),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: isHovered
                    ? Border.all(color: widget.currentThemeColor, width: 2.5)
                    : Border.all(color: Colors.transparent, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: isHovered
                        ? widget.currentThemeColor.withValues(alpha: 0.3)
                        : Colors.black12,
                    blurRadius: isHovered ? 12 : 6,
                    offset: isHovered ? const Offset(0, 6) : const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            decoration: (item.type == MissionType.checkbox &&
                                    item.isCompleted)
                                ? TextDecoration.lineThrough
                                : null,
                            color: (item.type == MissionType.checkbox &&
                                    item.isCompleted)
                                ? Colors.grey
                                : Colors.black87,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: widget.currentThemeColor
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.timeString,
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.currentThemeColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showMissionDialog(itemToEdit: item),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text('✏️', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                missions.removeAt(index);
                              });
                              _saveMissions();
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text('✕',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (item.type == MissionType.meter)
                    Row(
                      children: [
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: widget.currentThemeColor,
                              inactiveTrackColor: const Color(0xFFE2E8F0),
                              thumbColor: Colors.white,
                              overlayColor: widget.currentThemeColor
                                  .withValues(alpha: 0.2),
                              trackHeight: 6,
                            ),
                            child: Slider(
                              value: item.progress,
                              onChanged: (newValue) {
                                setState(() {
                                  item.progress = newValue;
                                });
                                _saveMissions();
                              },
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 45,
                          child: Text(
                            '${(item.progress * 100).round()}%',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: widget.currentThemeColor,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    CheckboxListTile(
                      title: const Text('完了', style: TextStyle(fontSize: 13)),
                      value: item.isCompleted,
                      activeColor: widget.currentThemeColor,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (bool? value) {
                        setState(() {
                          item.isCompleted = value ?? false;
                        });
                        _saveMissions();
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRightSideContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🕓 ', style: TextStyle(fontSize: 18)),
                  Text(
                    '24時間スケジュール',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.currentThemeColor),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              MouseRegion(
                onHover: (event) {
                  final RenderBox? box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;

                  // 24時間スケジュール上の角度判定
                  final center = const Offset(120, 120);
                  final dx = event.localPosition.dx - center.dx;
                  final dy = event.localPosition.dy - center.dy;

                  final distance = sqrt(dx * dx + dy * dy);
                  // 円環のヒット範囲判定
                  if (distance < 70 || distance > 120) {
                    if (hoveredMissionId != null) {
                      setState(() => hoveredMissionId = null);
                    }
                    return;
                  }

                  // 角度(ラジアン)から時間(0〜24)へ変換
                  double angle = atan2(dy, dx) + pi / 2;
                  if (angle < 0) angle += 2 * pi;
                  double hoveredHour = (angle / (2 * pi)) * 24;

                  String? matchedId;
                  for (var item in missions) {
                    if (item.startHour <= hoveredHour &&
                        hoveredHour <= item.endHour) {
                      matchedId = item.id;
                      break;
                    }
                  }

                  if (hoveredMissionId != matchedId) {
                    setState(() {
                      hoveredMissionId = matchedId;
                    });
                  }
                },
                onExit: (_) {
                  if (hoveredMissionId != null) {
                    setState(() => hoveredMissionId = null);
                  }
                },
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: CustomPaint(
                    painter: DynamicSchedulePainter(
                      missions: missions,
                      themeColor: widget.currentThemeColor,
                      hoveredMissionId: hoveredMissionId,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('⏱️ ', style: TextStyle(fontSize: 18)),
                  Text(
                    '集中タイマー',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.currentThemeColor),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _formattedTimerTime,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: _remainingSeconds == 0
                      ? Colors.red.shade400
                      : Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _isTimerRunning ? _pauseTimer : _startTimer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.currentThemeColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(_isTimerRunning ? '一時停止' : 'スタート'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _resetTimer,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('リセット'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Text('⚙️', style: TextStyle(fontSize: 18)),
                    onPressed: _showSetTimerDialog,
                    tooltip: '時間を指定',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DynamicSchedulePainter extends CustomPainter {
  final List<MissionItem> missions;
  final Color themeColor;
  final String? hoveredMissionId;

  DynamicSchedulePainter({
    required this.missions,
    required this.themeColor,
    this.hoveredMissionId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 32.0;

    final basePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, basePaint);

    for (var i = 0; i < missions.length; i++) {
      final item = missions[i];
      final isHovered = hoveredMissionId == item.id;

      final segmentPaint = Paint()
        ..color = isHovered
            ? themeColor
            : themeColor.withValues(alpha: 0.65 + (i % 3) * 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHovered ? strokeWidth + 6 : strokeWidth;

      final startAngle = -pi / 2 + (item.startHour / 24) * 2 * pi;
      final sweepAngle = ((item.endHour - item.startHour) / 24) * 2 * pi;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        segmentPaint,
      );
    }

    const textStyle = TextStyle(
      color: Colors.black54,
      fontSize: 11,
      fontWeight: FontWeight.bold,
    );

    void drawText(String text, Offset position) {
      final textSpan = TextSpan(text: text, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(position.dx - textPainter.width / 2,
            position.dy - textPainter.height / 2),
      );
    }

    drawText('0:00', Offset(center.dx, center.dy - radius + strokeWidth + 12));
    drawText('6:00', Offset(center.dx + radius - strokeWidth - 14, center.dy));
    drawText('12:00', Offset(center.dx, center.dy + radius - strokeWidth - 12));
    drawText('18:00', Offset(center.dx - radius + strokeWidth + 14, center.dy));
  }

  @override
  bool shouldRepaint(covariant DynamicSchedulePainter oldDelegate) => true;
}