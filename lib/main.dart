import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Học Lực Teacher Station',
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF5F5F5), // Màu nền xám nhạt như bản vẽ
      ),
      home: const TeacherStationPrototype(),
    );
  }
}

class TeacherStationPrototype extends StatelessWidget {
  const TeacherStationPrototype({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black54, width: 1.5),
            color: Colors.white,
          ),
          child: Column(
            children: [
              // 1. TOP HEADER
              _buildHeader(),
              const Divider(height: 1, thickness: 1.5, color: Colors.black54),
              
              // 2. MAIN BODY (3 Cột)
              Expanded(
                child: Row(
                  children: [
                    // Cột Trái: SCENES
                    Expanded(flex: 2, child: _buildLeftColumn()),
                    const VerticalDivider(width: 1, thickness: 1.5, color: Colors.black54),
                    
                    // Cột Giữa: TEACHING CANVAS
                    Expanded(flex: 5, child: _buildCenterCanvas()),
                    const VerticalDivider(width: 1, thickness: 1.5, color: Colors.black54),
                    
                    // Cột Phải: STUDENTS
                    Expanded(flex: 2, child: _buildRightColumn()),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1.5, color: Colors.black54),
              
              // 3. BOTTOM TOOLBAR
              _buildToolbar(),
            ],
          ),
        ),
      ),
    );
  }

  // ---- CÁC HÀM XÂY DỰNG GIAO DIỆN ----

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('HỌC LỰC TEACHER STATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Row(
            children: const [
              Text('LIVE ', style: TextStyle(fontWeight: FontWeight.bold)),
              Icon(Icons.circle, color: Colors.red, size: 12),
              SizedBox(width: 8),
              Text('01:23:42', style: TextStyle(fontFamily: 'monospace', fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn() {
    final scenes = ['Teacher', 'Board', 'Question', 'Solution', 'Student', 'Break'];
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('SCENES', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          ...scenes.map((scene) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Text(scene, style: const TextStyle(fontSize: 15)),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildCenterCanvas() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('TEACHING CANVAS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 40),
            const Text('x² + 5x + 6 = 0', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.edit, color: Colors.grey),
                SizedBox(width: 8),
                Text('handwriting...', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRightColumn() {
    final items = ['Chat', 'Raise Hand', 'Answers', 'Poll results', 'TA messages'];
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('STUDENTS', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Text(item, style: const TextStyle(fontSize: 15)),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _toolbarItem(Icons.mic, 'Voice'),
          _toolbarItem(Icons.videocam, 'Camera'),
          _toolbarItem(Icons.auto_fix_high, 'FX', iconColor: Colors.orange),
          _toolbarItem(Icons.timer, 'Timer'),
          _toolbarItem(Icons.quiz, 'Quiz'),
          _toolbarItem(Icons.movie_creation, 'Record', iconColor: Colors.purple),
        ],
      ),
    );
  }

  Widget _toolbarItem(IconData icon, String label, {Color iconColor = Colors.grey}) {
    return Row(
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 4),
        Text(label),
        const SizedBox(width: 16),
        const Text('|', style: TextStyle(color: Colors.black26)),
      ],
    );
  }
}
