class MeetChatMessage {
  final String id;
  final String sender;
  final String text;
  final String time;
  final bool isSelf;

  const MeetChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.time,
    this.isSelf = false,
  });

  factory MeetChatMessage.fromJson(Map<String, dynamic> json) {
    return MeetChatMessage(
      id: json['id'] as String? ?? '${DateTime.now().millisecondsSinceEpoch}',
      sender: json['sender'] as String? ?? 'Học sinh',
      text: json['text'] as String? ?? '',
      time: json['time'] as String? ?? '',
      isSelf: json['isSelf'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender': sender,
    'text': text,
    'time': time,
    'isSelf': isSelf,
  };
}

class MeetRaisedHandEvent {
  final int count;
  final List<String> names;

  const MeetRaisedHandEvent({required this.count, required this.names});

  factory MeetRaisedHandEvent.fromJson(Map<String, dynamic> json) {
    final rawNames = json['names'];
    final List<String> parsedNames = [];
    if (rawNames is List) {
      for (final item in rawNames) {
        if (item is String && item.trim().isNotEmpty) {
          parsedNames.add(item.trim());
        }
      }
    }
    return MeetRaisedHandEvent(
      count: json['count'] as int? ?? parsedNames.length,
      names: parsedNames,
    );
  }
}

class MeetAdmissionEvent {
  final int pendingCount;

  const MeetAdmissionEvent({required this.pendingCount});

  factory MeetAdmissionEvent.fromJson(Map<String, dynamic> json) {
    return MeetAdmissionEvent(pendingCount: json['pendingCount'] as int? ?? 1);
  }
}

class MeetParticipant {
  final String id;
  final String name;
  final bool isMuted;
  final bool isCameraOn;
  final bool isHandRaised;
  final bool isSpeaking;

  const MeetParticipant({
    required this.id,
    required this.name,
    this.isMuted = true,
    this.isCameraOn = true,
    this.isHandRaised = false,
    this.isSpeaking = false,
  });

  MeetParticipant copyWith({
    String? id,
    String? name,
    bool? isMuted,
    bool? isCameraOn,
    bool? isHandRaised,
    bool? isSpeaking,
  }) {
    return MeetParticipant(
      id: id ?? this.id,
      name: name ?? this.name,
      isMuted: isMuted ?? this.isMuted,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }

  factory MeetParticipant.fromJson(Map<String, dynamic> json) {
    return MeetParticipant(
      id: json['id'] as String? ?? '${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Học sinh',
      isMuted: json['isMuted'] as bool? ?? true,
      isCameraOn: json['isCameraOn'] as bool? ?? true,
      isHandRaised: json['isHandRaised'] as bool? ?? false,
      isSpeaking: json['isSpeaking'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isMuted': isMuted,
    'isCameraOn': isCameraOn,
    'isHandRaised': isHandRaised,
    'isSpeaking': isSpeaking,
  };
}

class MeetAdmissionRequest {
  final String id;
  final String name;
  final String detail;

  const MeetAdmissionRequest({
    required this.id,
    required this.name,
    this.detail = '',
  });

  factory MeetAdmissionRequest.fromJson(Map<String, dynamic> json) =>
      MeetAdmissionRequest(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
      );
}
