import 'package:flutter/material.dart';
import 'package:memogenerator/resources/app_colors.dart';
import 'package:memogenerator/resources/app_images.dart';

class EasterEggPage extends StatelessWidget {
  const EasterEggPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.lemon,
        foregroundColor: AppColors.darkGrey,
      ),
      body: RocketAnimationBody(),
    );
  }
}

class RocketAnimationBody extends StatefulWidget {
  const RocketAnimationBody({Key? key}) : super(key: key);

  @override
  State<RocketAnimationBody> createState() => _RocketAnimationBodyState();
}

class _RocketAnimationBodyState extends State<RocketAnimationBody>
    with SingleTickerProviderStateMixin {
  static const animationDurationSeconds = 10; // привязка ко времени

  late AnimationController controller;
  late Animation<Alignment> rocketPositionAnimation; // для позиции
  late Animation<double> rocketScaleAnimation; // кривая полета ракеты
  late Animation<double> fireRotationAnimation; // дрожащий огонь
  late Animation<double> glowScaleAnimation; // показывает и убирает виджет

  bool started = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: animationDurationSeconds),
    );
    // при достижении ракеты верха, возвращается вниз
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.reset();
        setState(() => started = false);
      }
    });

    rocketPositionAnimation = AlignmentTween(
      begin: Alignment(0, 0.9),
      end: Alignment(0, -1),
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(0.1, 0.8, curve: Curves.easeInCubic),
      ),
    );

    rocketScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(0.3, 0.8, curve: Curves.easeInCubic),
      ),
    );
    // анимация огня
    fireRotationAnimation = TweenSequence(
      [
        TweenSequenceItem(
          tween: Tween<double>(begin: 0.005, end: -0.005),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: -0.005, end: 0.005),
          weight: 50,
        ),
      ],
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve:
            Interval(0.0, 0.8, curve: SawTooth(animationDurationSeconds * 5)),
      ),
    );
    glowScaleAnimation = TweenSequence(
      [
        TweenSequenceItem(
          tween: Tween<double>(begin: 0, end: 1),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1, end: 0),
          weight: 50,
        ),
      ],
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(0.8, 0.9),
      ),
    );
  }

  void animate() {
    if (controller.isAnimating) {
      return;
    }
    setState(() => started = true);
    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
                image: AssetImage(AppImages.starsPattern),
                repeat: ImageRepeat.repeat),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.elliptical(constraints.maxWidth, 200),
                    ),
                    color: Colors.green[700],
                  ),
                ),
              ),
              if (started)
                AlignTransition(
                  alignment: rocketPositionAnimation,
                  child: RotationTransition(
                    turns: fireRotationAnimation,
                    child: ScaleTransition(
                      scale: rocketScaleAnimation,
                      child: Image.asset(
                        AppImages.rocketFire,
                        height: 200,
                      ),
                    ),
                  ),
                ),
              GestureDetector(
                onTap: () => animate(),
                child: AlignTransition(
                  alignment: rocketPositionAnimation,
                  child: ScaleTransition(
                    scale: rocketScaleAnimation,
                    child: Image.asset(
                      AppImages.rocketWithoutFire,
                      height: 200,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 70,
                left: constraints.maxWidth / 2 - 40,
                child: ScaleTransition(
                  // убирает и показывает виджет
                  scale: glowScaleAnimation,
                  child: Image.asset(AppImages.starGlow, height: 50),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
