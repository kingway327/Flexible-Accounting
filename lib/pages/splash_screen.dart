import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/database_helper.dart';

/// 启动动画页面
/// 根据当前时间自动选择白天/夜晚视频，约3.33倍速播放（6秒→1.8秒），静音
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.isDaytime,
    required this.markShownOnFinish,
    required this.onFinished,
  });

  final bool isDaytime;
  final bool markShownOnFinish;
  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _db = DatabaseHelper.instance;
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    final videoPath = widget.isDaytime
        ? 'assets/splash/splash_day.mp4'
        : 'assets/splash/splash_night.mp4';

    _controller = VideoPlayerController.asset(videoPath)
      ..initialize().then((_) {
        final controller = _controller;
        if (controller == null) return;
        if (!mounted) return;
        setState(() => _initialized = true);
        // 静音
        controller.setVolume(0.0);
        // 约3.33倍速播放（6秒→1.8秒）
        controller.setPlaybackSpeed(3.33);
        controller.setLooping(false);
        controller.play();

        // 监听播放完成
        controller.addListener(_onVideoProgress);
      }).catchError((error) {
        // 视频加载失败，直接跳转主页
        _finish();
      });
  }

  Future<void> _onVideoProgress() async {
    final controller = _controller;
    if (controller == null) return;
    if (!mounted) return;
    final position = controller.value.position;
    final duration = controller.value.duration;

    // 视频播放完成或接近完成
    if (duration.inMilliseconds > 0 &&
        position.inMilliseconds >= duration.inMilliseconds - 100) {
      controller.removeListener(_onVideoProgress);
      if (widget.markShownOnFinish) {
        await _db.markStartupAnimationShownOnce();
      }
      if (!mounted) return;
      _finish();
    }
  }

  void _finish() {
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDaytime ? Colors.white : Colors.black;
    final overlayColor = widget.isDaytime
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.18);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: _initialized
          ? Stack(
              fit: StackFit.expand,
              children: [
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                ),
                ColoredBox(color: overlayColor),
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}
