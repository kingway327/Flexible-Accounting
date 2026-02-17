import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/app_settings_dao.dart';

/// 启动动画页面
/// 根据当前时间自动选择白天/夜晚视频，加速播放并静音
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
  static const _kPlaybackSpeed = 2.8;
  static const _kExitFadeDuration = Duration(milliseconds: 220);
  static const _kBackdropBlurSigma = 14.0;

  final _settingsDao = AppSettingsDao.instance;
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isExiting = false;
  bool _finishStarted = false;

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
        // 提升播放速度，缩短等待时长
        controller.setPlaybackSpeed(_kPlaybackSpeed);
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
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_finishStarted) {
      return;
    }
    _finishStarted = true;
    _controller?.removeListener(_onVideoProgress);
    if (widget.markShownOnFinish) {
      await _settingsDao.markStartupAnimationShownOnce();
    }
    if (!mounted) return;
    setState(() => _isExiting = true);
    await Future<void>.delayed(_kExitFadeDuration);
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoProgress);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDaytime ? Colors.white : Colors.black;
    final backdropOverlayColor = widget.isDaytime
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.28);
    final edgeMaskColor = widget.isDaytime
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.18);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: AnimatedOpacity(
        opacity: _isExiting ? 0 : 1,
        duration: _kExitFadeDuration,
        curve: Curves.easeOutCubic,
        child: _initialized
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: backgroundColor),
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: _kBackdropBlurSigma,
                      sigmaY: _kBackdropBlurSigma,
                    ),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  ),
                  ColoredBox(color: backdropOverlayColor),
                  Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (Rect rect) {
                          return const RadialGradient(
                            center: Alignment.center,
                            radius: 1.08,
                            colors: [
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: [0, 0.92, 1],
                          ).createShader(rect);
                        },
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.06,
                        colors: [Colors.transparent, edgeMaskColor],
                        stops: const [0.74, 1],
                      ),
                    ),
                  ),
                ],
              )
            : ColoredBox(color: backgroundColor),
      ),
    );
  }
}
