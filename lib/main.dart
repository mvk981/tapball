import 'dart:io';
import 'dart:math';
import 'dart:core';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:confirm_dialog/confirm_dialog.dart';
import 'package:alert_dialog/alert_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:flutter/cupertino.dart';
// import 'package:window_size/window_size.dart';

void main() {
  // if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
  //   setWindowTitle("My Desktop App");
  //   setWindowMinSize(Size(375, 750));
  //   setWindowMaxSize(Size(600, 1000));
  // }
  runApp(App());
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Home(),
    );
  }
}

int save_difficulty = 2;

int maxX = 5;
int maxY = 6;
int minX = -maxX;
int minY = -maxY;
int max_steps = maxY * 2 - 1;

int STEP_DELAY = 200;
int _EXCLUDED_ = 0;
int _FREE_ = 1;
int _ANALYSED_ = 2;
int _USED_ = 3;
int _USED_USER_ = 4;
int _USED_COMP_ = 5;

double field_indent = 0;
double cell_size = 0;

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  SharedPreferences prefs;

  DrawableRoot svgRoot;

  int difficulty;
  bool stepOver = false;

  double bestCrit = 0;
  int recursion_depth = 0;
  int user_recursion_depth = 0;

  int ball_x = 0;
  int ball_y = 0;

  bool won = false;
  bool lose = false;

  bool onToachEventEnable = true;
  var rgen = new Random();

  List<List<List<List<int>>>> vectors;
  List<Point> currStepSeries = [];
  List<Point> bestStepSeries = [];
  List<Point> userStepSeries = [];

  void setVectorState(int x, int y, int vx, int vy, int value) {
    vectors[x + maxX][y + maxY][vx + 1][vy + 1] = value;
    if (x + vx >= minX && x + vx <= maxX && y + vy >= minY && y + vy <= maxY)
      vectors[x + maxX + vx][y + maxY + vy][-vx + 1][-vy + 1] = value;
  }

  int getVectorState(int x, int y, int vx, int vy) {
    if ((x == 0 && y == minY + 1 && vy == 1) ||
        (x == 0 && y == maxY - 1 && vy == -1))
      return _EXCLUDED_;
    else
      return vectors[x + maxX][y + maxY][vx + 1][vy + 1];
  }

  bool isDeadLock(int x, int y) {
    int count = 0;
    for (int vx = -1; vx <= 1; vx++) {
      for (int vy = -1; vy <= 1; vy++) {
        if (vx == 0 && vy == 0) continue;
        if (getVectorState(x, y, vx, vy) == _FREE_) {
          count++;
          if (count == 2) return false;
        }
      }
    }
    return true;
  }

  bool isStepOver(int x, int y) {
    int count = 0;
    // int state = 0;
    for (int vx = -1; vx <= 1; vx++) {
      for (int vy = -1; vy <= 1; vy++) {
        if (vx == 0 && vy == 0) continue;
        int state = getVectorState(x, y, vx, vy);
        if (state != _FREE_) {
          count++;
          if (count == 2) return false;
        }
      }
    }
    return true;
  }

  bool isGoal(int x, int y, int vy, bool user) {
    if (user && x == 0 && y == minY + 1 && vy < 0) {
      // goal = true;
      return true;
    } else if (!user && x == 0 && y == maxY - 1 && vy > 0) {
      // goal = true;
      return true;
    } else
      return false;
  }

  double PointToChoord(int point, int max) {
    return (field_indent + cell_size * max + point * cell_size).toDouble();
  }

  List<int> getDirectionY(int y, bool user) {
    if (user) {
      List<int> result = [-1, 0, 1];
      return result;
    } else {
      List<int> result = [1, 0, -1];
      return result;
    }
  }

  List<int> getDirectionX(int x) {
    if (x > 0) {
      List<int> result = [-1, 0, 1];
      return result;
    } else if (x < 0) {
      List<int> result = [1, 0, -1];
      return result;
    } else {
      double r = rgen.nextDouble() - 0.5;
      if (r < 0) {
        List<int> result = [0, -1, 1];
        return result;
      } else {
        List<int> result = [0, 1, -1];
        return result;
      }
    }
  }

  void SaveBestSeries(bool user) {
    bestStepSeries.clear();
    stdout.write("$user");
    for (int i = 0; i < currStepSeries.length; i++) {
      bestStepSeries.add(currStepSeries[i]);
      stdout.write("(${currStepSeries[i].x},${currStepSeries[i].y})");
    }
    stdout.write("\n");
  }

  bool AnalyseSteps(int x, int y, bool user) {
    bool goal = false;
    for (int vy in getDirectionY(y, user)) {
      for (int vx in getDirectionX(x)) {
        if (goal) {
          return goal;
        }
        if (vx == 0 && vy == 0) continue;
        if (isGoal(x + vx, y + vy, vy, user)) {
          if (!user) {
            Point vector = new Point(vx, vy);
            currStepSeries.add(vector);
            SaveBestSeries(user);
          }
          return true;
        }
        int state = getVectorState(x, y, vx, vy);
        if (state != _FREE_) continue;
        if (isGoal(x + vx, y + vy, vy, !user)) continue;
        if (isDeadLock(x + vx, y + vy)) continue;
        Point vector = new Point(vx, vy);
        if (!user)
          currStepSeries.add(vector);
        else
          userStepSeries.add(vector);
        setVectorState(x, y, vx, vy, _ANALYSED_);

        if (!isStepOver(x + vx, y + vy)) {
          if (!user) {
            if (recursion_depth < difficulty) {
              recursion_depth++;
              goal = AnalyseSteps(x + vx, y + vy, user);
              recursion_depth--;
            }
          } else if (user_recursion_depth < difficulty) {
            user_recursion_depth++;
            goal = AnalyseSteps(x + vx, y + vy, user);
            user_recursion_depth--;
          }
        } else {
          if (!user) {
            userStepSeries.clear();
            if (!AnalyseSteps(x + vx, y + vy, true)) {
              // int currCrit = 0;
              // int v1 = max_steps -
              //     (max((x + vx).abs(), ((maxY - 1) - (y + vy)).abs()));
              // int v2 = max((x + vx).abs(), ((minY + 1) - (y + vy)).abs());
              // int v3 =
              //     (max(((x + vx) - ball_x).abs(), ((y + vy) - ball_y)).abs() *
              //             max_steps /
              //             currStepSeries.length)
              //         .round();
              // int v4 = rgen.nextInt(max_steps);
              // currCrit = v1 * 40 + v2 * 30 + v3 * 29 + v4 * 1;
              int dy = maxY + y + vy;
              int dx = (x + vx).abs();
              double currCrit = dy -
                  dx / 2 +
                  // 1 / currStepSeries.length +
                  rgen.nextDouble() / 10;
              if (currCrit > bestCrit) {
                print(currCrit);
                SaveBestSeries(user);
                bestCrit = currCrit;
              }
            }
          }
        }
        if (!user)
          currStepSeries.removeAt(currStepSeries.length - 1);
        else
          userStepSeries.removeAt(userStepSeries.length - 1);
        setVectorState(x, y, vx, vy, state);
      }
    }
    return goal;
  }

  initGame() async {
    prefs = await SharedPreferences.getInstance();
    save_difficulty = prefs.getInt('difficulty') ?? 2;
    setState(() {
      stepOver = false;
      onToachEventEnable = true;
      // goal = false;

      bestCrit = 0;
      recursion_depth = 0;
      user_recursion_depth = 0;

      currStepSeries.clear();
      bestStepSeries.clear();
      userStepSeries.clear();

      ball_x = 0;
      ball_y = 0;

      won = false;
      lose = false;

      vectors = List.generate(
          maxX * 2 + 1,
          (i) => List.generate(
              maxY * 2 + 1,
              // ignore: deprecated_member_use
              (j) => List.generate(3, (k) => List(3))));

      for (int x = minX; x <= maxX; x++) {
        for (int y = minY; y <= maxY; y++) {
          for (int vx = -1; vx <= 1; vx++) {
            for (int vy = -1; vy <= 1; vy++) {
              setVectorState(x, y, vx, vy, _FREE_);
            }
          }
        }
      }

      // set vectors
      for (int i = minX; i <= maxX; i++) {
        // top line
        setVectorState(i, minY, -1, 0, _EXCLUDED_);
        setVectorState(i, minY, -1, -1, _EXCLUDED_);
        setVectorState(i, minY, 0, -1, _EXCLUDED_);
        setVectorState(i, minY, 1, -1, _EXCLUDED_);
        setVectorState(i, minY, 1, 0, _EXCLUDED_);
        // center line
        setVectorState(i, 0, -1, 0, _EXCLUDED_);
        setVectorState(i, 0, 1, 0, _EXCLUDED_);
        // bottom line
        setVectorState(i, maxY, -1, 0, _EXCLUDED_);
        setVectorState(i, maxY, -1, 1, _EXCLUDED_);
        setVectorState(i, maxY, 0, 1, _EXCLUDED_);
        setVectorState(i, maxY, 1, 1, _EXCLUDED_);
        setVectorState(i, maxY, 1, 0, _EXCLUDED_);
      }
      for (int j = minY; j <= maxY; j++) {
        // left line
        setVectorState(minX, j, 0, -1, _EXCLUDED_);
        setVectorState(minX, j, -1, -1, _EXCLUDED_);
        setVectorState(minX, j, -1, 0, _EXCLUDED_);
        setVectorState(minX, j, -1, 1, _EXCLUDED_);
        setVectorState(minX, j, 0, 1, _EXCLUDED_);
        // right line
        setVectorState(maxX, j, 0, -1, _EXCLUDED_);
        setVectorState(maxX, j, 1, -1, _EXCLUDED_);
        setVectorState(maxX, j, 1, 0, _EXCLUDED_);
        setVectorState(maxX, j, 1, 1, _EXCLUDED_);
        setVectorState(maxX, j, 0, 1, _EXCLUDED_);
      }
      // top gate
      setVectorState(0, minY + 1, -1, 0, _EXCLUDED_);
      setVectorState(0, minY + 1, 1, 0, _EXCLUDED_);
      // bottom gate
      setVectorState(0, maxY - 1, -1, 0, _EXCLUDED_);
      setVectorState(0, maxY - 1, 1, 0, _EXCLUDED_);
    });
  }

  void loadUiImage(String imageAssetPath) async {
    final String rawSvg = await rootBundle.loadString(imageAssetPath);
    final DrawableRoot drawableRoot = await svg.fromSvgString(rawSvg, rawSvg);
    setState(() => svgRoot = drawableRoot);
  }

  @override
  void initState() {
    super.initState();
    loadUiImage('packages/tapball/assets/ball.svg');
    initGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
          preferredSize: Size.fromHeight(50.0),
          child: AppBar(
            title: Text("Tapball"),
            centerTitle: true,
          )),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                    child: CustomPaint(
                      painter: Painter(this),
                      size: Size(constraints.maxWidth,
                          constraints.maxWidth + cell_size * 2),
                    ),
                    onTapUp: (TapUpDetails details) => _onTapUp(details)),
                Spacer(),
                NumberPicker(
                  value: save_difficulty,
                  minValue: 2,
                  maxValue: 9,
                  step: 1,
                  onChanged: (value) async {
                    await prefs.setInt('difficulty', value);
                    setState(() {
                      save_difficulty = value;
                    });
                  },
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Text('Difficulty',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ]);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (won || lose) {
            return initGame();
          } else if (await confirm(
            context,
            title: Text('Restart game'),
            content: Text('Are you sure?'),
            textOK: Text('Yes'),
            textCancel: Text('No'),
          )) {
            return initGame();
          }
          return;
        },
        label: Text('Restart'),
        icon: Icon(Icons.restart_alt),
      ),
    );
  }

  void MoveBall(int vx, int vy, int state) {
    setState(() {
      setVectorState(ball_x, ball_y, vx, vy, state);
      ball_x = ball_x + vx;
      ball_y = ball_y + vy;
    });
  }

  void ConfirmSeries(bool user) {
    int x = ball_x;
    int y = ball_y;
    for (int i = bestStepSeries.length - 1; i >= 0; i--) {
      int vx = bestStepSeries[i].x;
      int vy = bestStepSeries[i].y;
      if (user)
        setVectorState(x, y, -vx, -vy, _USED_USER_);
      else
        setVectorState(x, y, -vx, -vy, _USED_COMP_);
      x = x - vx;
      y = y - vy;
    }
    currStepSeries.clear();
    bestStepSeries.clear();
    // postInvalidate();
  }

  _onTapUp(TapUpDetails details) async {
    if (!onToachEventEnable) return;

    var x = details.localPosition.dx;
    var y = details.localPosition.dy;

    // get direction
    int vx = 0;
    int vy = 0;
    double x1 = PointToChoord(ball_x, maxX);
    double y1 = PointToChoord(ball_y, maxY);
    double angle = atan2(y - y1, x - x1) * 180 / pi;

    if ((angle < -157) || (angle >= 157)) {
      vx = -1;
      vy = 0;
    } else if ((angle >= -157) && (angle < -112)) {
      vx = -1;
      vy = -1;
    } else if ((angle >= -112) && (angle < -67)) {
      vx = 0;
      vy = -1;
    } else if ((angle >= -67) && (angle < -22)) {
      vx = 1;
      vy = -1;
    } else if ((angle >= -22) && (angle < 22)) {
      vx = 1;
      vy = 0;
    } else if ((angle >= 22) && (angle < 67)) {
      vx = 1;
      vy = 1;
    } else if ((angle >= 67) && (angle < 112)) {
      vx = 0;
      vy = 1;
    } else if ((angle >= 112) && (angle < 157)) {
      vx = -1;
      vy = 1;
    }
    // undo step if needed
    int size = currStepSeries.length;
    if (size > 0) {
      if (vx + currStepSeries[size - 1].x == 0 &&
          vy + currStepSeries[size - 1].y == 0) {
        currStepSeries.removeAt(currStepSeries.length - 1);
        setVectorState(ball_x, ball_y, vx, vy, _FREE_);
        MoveBall(vx, vy, _FREE_);
        stepOver = false;
        return;
      }
    }

    if (!stepOver) {
      if (isGoal(ball_x + vx, ball_y + vy, vy, true)) {
        won = true;
      } else if (isGoal(ball_x + vx, ball_y + vy, vy, false)) {
        return;
      } else if (getVectorState(ball_x, ball_y, vx, vy) != _FREE_) {
        return;
      } else if (isDeadLock(ball_x + vx, ball_y + vy)) {
        return;
      }

      if (bestStepSeries.length > 0) ConfirmSeries(false);

      Point vector = new Point(vx, vy);
      currStepSeries.add(vector);
      MoveBall(vx, vy, _USED_);

      if (won) {
        onToachEventEnable = false;
      }

      if (isStepOver(ball_x, ball_y)) {
        stepOver = true;
        return;
      }
    } else if (vx - currStepSeries[size - 1].x == 0 &&
        vy - currStepSeries[size - 1].y == 0) {
      SaveBestSeries(true);

      onToachEventEnable = false;

      ConfirmSeries(true);
      bestCrit = 0;
      recursion_depth = 0;
      user_recursion_depth = 0;
      difficulty = save_difficulty - 2;
      do {
        difficulty++;
        if (difficulty > 9) break;
        lose = AnalyseSteps(ball_x, ball_y, false);
        print(difficulty + 1);
      } while (bestStepSeries.length == 0);

      if (bestStepSeries.length == 0) {
        won = true;
        onToachEventEnable = false;
      } else {
        for (int i = 0; i < bestStepSeries.length; i++) {
          await Future.delayed(const Duration(milliseconds: 200), () {
            MoveBall(bestStepSeries[i].x, bestStepSeries[i].y, _USED_);
          });
        }
      }
      if (lose) {
        onToachEventEnable = false;
      } else {
        onToachEventEnable = true;
      }
      stepOver = false;
    }
    if (won)
      await Future.delayed(const Duration(milliseconds: 200), () {
        alert(context,
            title: Text('Congratulations'),
            content: Text('You won!'),
            textOK: Text('ok'));
      });
    if (lose)
      await Future.delayed(const Duration(milliseconds: 200), () {
        alert(context,
            title: Text('Congratulations'),
            content: Text('You lose!'),
            textOK: Text('ok'));
      });
  }
}

class Painter extends CustomPainter {
  Painter(this.hs);
  _HomeState hs;

  @override
  void paint(Canvas canvas, Size size) {
    field_indent = size.width / ((maxX * 2) * 2);
    cell_size = (size.width - field_indent * 2) / (maxX * 2);

    Paint paint = Paint()
      ..strokeWidth = cell_size / 20
      ..color = Colors.grey
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..filterQuality = FilterQuality.high;

    for (int i = 1; i <= maxX * 2 - 1; i++) {
      canvas.drawLine(
          Offset(field_indent + cell_size * i, field_indent),
          Offset(field_indent + cell_size * i,
              field_indent + maxY * cell_size * 2),
          paint);
    }
    for (int i = 1; i <= maxY * 2 - 1; i++) {
      canvas.drawLine(
          Offset(field_indent, field_indent + cell_size * i),
          Offset(field_indent + maxX * 2 * cell_size,
              field_indent + cell_size * i),
          paint);
    }

    // draw circle
    canvas.drawCircle(
        Offset(
            field_indent + maxX * cell_size, field_indent + maxY * cell_size),
        cell_size,
        paint);

    // draw arcs
    Rect rect = Rect.fromPoints(
        Offset(field_indent + maxX * cell_size - cell_size, field_indent),
        Offset(field_indent + maxX * cell_size + cell_size,
            field_indent + cell_size * 2));
    canvas.drawArc(rect, pi, -pi, true, paint);

    rect = Rect.fromPoints(
        Offset(field_indent + maxX * cell_size - cell_size,
            field_indent + maxY * cell_size * 2 - cell_size * 2),
        Offset(field_indent + maxX * cell_size + cell_size,
            field_indent + maxY * cell_size * 2));
    canvas.drawArc(rect, pi, pi, true, paint);

    // draw field borders
    paint.color = Colors.grey[800];

    canvas.drawLine(Offset(field_indent, field_indent),
        Offset(maxX * cell_size * 2 + field_indent, field_indent), paint);
    canvas.drawLine(
        Offset(maxX * cell_size * 2 + field_indent, field_indent),
        Offset(maxX * cell_size * 2 + field_indent,
            maxY * cell_size * 2 + field_indent),
        paint);
    canvas.drawLine(
        Offset(maxX * cell_size * 2 + field_indent,
            maxY * cell_size * 2 + field_indent),
        Offset(field_indent, maxY * cell_size * 2 + field_indent),
        paint);
    canvas.drawLine(Offset(field_indent, maxY * cell_size * 2 + field_indent),
        Offset(field_indent, field_indent), paint);

    // draw center line
    canvas.drawLine(
        Offset(field_indent, field_indent + maxY * cell_size),
        Offset(field_indent + maxX * cell_size * 2,
            field_indent + maxY * cell_size),
        paint);

    // draw gates
    canvas.drawLine(
        Offset(field_indent + maxX * cell_size - cell_size,
            field_indent + cell_size),
        Offset(field_indent + maxX * cell_size + cell_size,
            field_indent + cell_size),
        paint);
    canvas.drawLine(
        Offset(field_indent + maxX * cell_size - cell_size,
            field_indent + maxY * cell_size * 2 - cell_size),
        Offset(field_indent + maxX * cell_size + cell_size,
            field_indent + maxY * cell_size * 2 - cell_size),
        paint);

    // draw vectors
    paint.strokeWidth = cell_size / 10;
    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        for (int vx = -1; vx <= 1; vx++) {
          for (int vy = -1; vy <= 1; vy++) {
            int state = hs.getVectorState(x, y, vx, vy);
            if (state == _USED_) {
              paint.color = Colors.green;
              canvas.drawLine(
                  Offset(hs.PointToChoord(x, maxX), hs.PointToChoord(y, maxY)),
                  Offset(hs.PointToChoord(x + vx, maxX),
                      hs.PointToChoord(y + vy, maxY)),
                  paint);
            } else if (state == _USED_USER_) {
              paint.color = Colors.blue[900];
              canvas.drawLine(
                  Offset(hs.PointToChoord(x, maxX), hs.PointToChoord(y, maxY)),
                  Offset(hs.PointToChoord(x + vx, maxX),
                      hs.PointToChoord(y + vy, maxY)),
                  paint);
            } else if (state == _USED_COMP_) {
              paint.color = Colors.red;
              canvas.drawLine(
                  Offset(hs.PointToChoord(x, maxX), hs.PointToChoord(y, maxY)),
                  Offset(hs.PointToChoord(x + vx, maxX),
                      hs.PointToChoord(y + vy, maxY)),
                  paint);
            } else if (state == _ANALYSED_) {
              paint.color = Colors.indigo[200];
              canvas.drawLine(
                  Offset(hs.PointToChoord(x, maxX), hs.PointToChoord(y, maxY)),
                  Offset(hs.PointToChoord(x + vx, maxX),
                      hs.PointToChoord(y + vy, maxY)),
                  paint);
            }
          }
        }
      }
    }

    // draw ball
    paint.color = Colors.white;
    paint.strokeWidth = 0;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(hs.PointToChoord(hs.ball_x, maxX),
            hs.PointToChoord(hs.ball_y, maxY)),
        cell_size / 2,
        paint);

    Size desiredSize = Size(cell_size, cell_size);
    canvas.save();
    canvas.translate(hs.PointToChoord(hs.ball_x, maxX) - cell_size / 2,
        hs.PointToChoord(hs.ball_y, maxY) - cell_size / 2);

    Size svgSize = hs.svgRoot.viewport.size;
    var matrix = Matrix4.identity();
    matrix.scale(
        desiredSize.width / svgSize.width, desiredSize.height / svgSize.height);
    canvas.transform(matrix.storage);
    hs.svgRoot.draw(canvas, Rect.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter old) {
    return true;
  }
}

class Point {
  int x;
  int y;
  Point(this.x, this.y);
}
