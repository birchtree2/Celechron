import 'package:celechron/model/period.dart';
import 'package:get/get.dart';

import 'grade.dart';
import 'semester.dart';
import '../http/spider.dart';
import 'package:celechron/database/database_helper.dart';

class User {
  // 构造用户对象
  User();

  final DatabaseHelper _db = Get.find<DatabaseHelper>(tag: 'db');
  // 登录状态
  bool isLogin = false;
  DateTime lastUpdateTime = DateTime.parse("20010101");

  // 爬虫区
  late String username;
  late String _password;
  late Spider _spider;

  // 按学期整理好的详细数据，包括该学期的所有科目、考试、课表、均绩等
  List<Semester> semesters = <Semester>[];

  // 按课程号整理好的成绩单，方便算重修成绩
  Map<String, List<Grade>> grades = {};

  // 保研GPA, 三个数据依次为五分制，四分制，百分制
  List<double> gpa = [0.0, 0.0, 0.0];

  // 出国GPA, 三个数据依次为五分制，四分制，百分制
  List<double> aboardGpa = [0.0, 0.0, 0.0];

  // 所获学分
  double credit = 0.0;

  // 主修数据，两个数据依次为主修GPA，主修学分
  List<double> majorGpaAndCredit = [0.0, 0.0];

  set password(String password) {
    _password = password;
  }

  List<Period> get coursePeriods {
    return semesters.fold(<Period>[], (p, e) => p + e.periods);
  }

  Semester get thisSemester {
    if (semesters.isNotEmpty) {
      return semesters.first;
    } else {
      return Semester('未刷新');
    }
  }

  // 初始化以获取Cookies，并刷新数据
  Future<List<String?>> login() async {
    _spider = Spider(username, _password);
    var loginErrorMessage = await _spider.login();
    if (loginErrorMessage.every((e) => e == null)) {
      isLogin = true;
      _db.setUser(this);
    }
    return loginErrorMessage;
  }

  Future<bool> logout() async {
    username = "";
    _password = "";
    semesters = [];
    grades = {};
    gpa = [0.0, 0.0, 0.0];
    aboardGpa = [0.0, 0.0, 0.0];
    credit = 0.0;
    majorGpaAndCredit = [0.0, 0.0];
    isLogin = false;
    lastUpdateTime = DateTime.parse("20010101");
    _spider.logout();
    return _db.removeUser().then((value) => true).catchError((e) => false);
  }

  // 刷新数据
  Future<List<String?>> refresh() async {
    return await _spider
        .getEverything()
        .then((value) async {
          for (var e in value.item1) {
            if(e != null) print(e);
          }
          for (var e in value.item2) {
            if(e != null) print(e);
          }
      if (value.item1.every((e) => e == null) && value.item2.every((e) => e == null)) {
        lastUpdateTime = DateTime.now();
      }
      semesters = value.item3;
      grades = value.item4;
      majorGpaAndCredit = value.item5;
      // 保研成绩，只取第一次
      var netGrades = grades.values.map((e) => e.first);
      if (netGrades.isNotEmpty) {
        gpa = Grade.calculateGpa(netGrades);
      }
      // 出国成绩，取最高的一次
      var aboardNetGrades = grades.values.map((e) {
        e.sort((a, b) => a.hundredPoint.compareTo(b.hundredPoint));
        return e.last;
      });
      if (aboardNetGrades.isNotEmpty) {
        aboardGpa = Grade.calculateGpa(aboardNetGrades);
      }
      // 这个算的是所获学分，不包括挂科的。因为出国成绩单取最高的一次成绩，所以就把挂科的学分算对了
      credit =
          aboardNetGrades.fold<double>(0.0, (p, e) => p + e.effectiveCredit);
      await _db.setUser(this);
      return value.item1.every((e) => e == null) ? value.item2 : value.item1;
    });
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': _password,
      'semesters': semesters,
      'grades': grades,
      'gpa': gpa,
      'aboardGpa': aboardGpa,
      'credit': credit,
      'majorGpaAndCredit': majorGpaAndCredit,
      'lastUpdateTime' : lastUpdateTime.toIso8601String(),
    };
  }

  User.fromJson(Map<String, dynamic> json) {
    username = json['username'];
    _password = json['password'];
    _spider = Spider(username, _password);
    semesters =
        (json['semesters'] as List).map((e) => Semester.fromJson(e)).toList();
    grades = (json['grades'] as Map<String, dynamic>).map((key, value) {
      return MapEntry(
          key, (value as List).map((e) => Grade.fromJson(e)).toList());
    });
    gpa = List<double>.from(json['gpa']);
    aboardGpa = List<double>.from(json['aboardGpa']);
    credit = json['credit'];
    majorGpaAndCredit = List<double>.from(json['majorGpaAndCredit']);
    lastUpdateTime = DateTime.parse(json['lastUpdateTime']);
    isLogin = true;
  }
}
