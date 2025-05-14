import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class MealPlanCalendarScreen extends StatefulWidget {
  final Map<String, dynamic>? mealPlan;
  final Function(DateTime) onDateSelected;

  const MealPlanCalendarScreen({
    required this.mealPlan,
    required this.onDateSelected,
    super.key,
  });

  @override
  State<MealPlanCalendarScreen> createState() => _MealPlanCalendarScreenState();
}

class _MealPlanCalendarScreenState extends State<MealPlanCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<int, Color>? _mealTypeColors;
  double _rowHeight = 100.0;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _generateMealTypeColors();
    _calculateRowHeight();
  }

  void _generateMealTypeColors() {
    final random = Random();
    _mealTypeColors = {};
    if (widget.mealPlan == null || widget.mealPlan!['meal_types'] == null) return;

    final mealTypes = (widget.mealPlan!['meal_types'] as List<dynamic>).cast<Map<String, dynamic>>();
    for (var mealType in mealTypes) {
      final mealTypeId = mealType['id'] as int;
      _mealTypeColors![mealTypeId] = Color.fromRGBO(
        200 + random.nextInt(56),
        200 + random.nextInt(56),
        200 + random.nextInt(56),
        1.0,
      );
    }
  }

  Map<DateTime, List<Map<String, dynamic>>> _getEvents() {
    final events = <DateTime, List<Map<String, dynamic>>>{};
    if (widget.mealPlan == null || widget.mealPlan!['plan'] == null) return events;

    final mealTypes = (widget.mealPlan!['meal_types'] as List<dynamic>).cast<Map<String, dynamic>>();
    final plan = widget.mealPlan!['plan'] as Map<String, dynamic>;
    plan.forEach((dateStr, meals) {
      final date = DateTime.parse(dateStr);
      final mealList = <Map<String, dynamic>>[];
      (meals as Map<String, dynamic>).forEach((mealTypeId, recipeId) {
        final mealType = mealTypes.firstWhere(
              (mt) => mt['id'].toString() == mealTypeId,
          orElse: () => {'id': int.parse(mealTypeId), 'name': 'Unknown'},
        );
        mealList.add({
          'mealTypeId': int.parse(mealTypeId),
          'mealTypeName': mealType['name'],
        });
      });
      events[DateTime(date.year, date.month, date.day)] = mealList;
    });

    return events;
  }

  void _calculateRowHeight() {
    final events = _getEvents();
    int maxEvents = 0;

    events.forEach((date, eventList) {
      if (date.month == _focusedDay.month && date.year == _focusedDay.year) {
        maxEvents = eventList.length > maxEvents ? eventList.length : maxEvents;
      }
    });

    setState(() {
      _rowHeight = 48.0 + (maxEvents * 22.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final events = _getEvents();
    Intl.defaultLocale = 'ru_RU';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                  _calculateRowHeight();
                });
              },
            ),
            Text(
              DateFormat('MMMM', 'ru_RU').format(_focusedDay).toUpperCase(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 20),
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                  _calculateRowHeight();
                });
              },
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          widget.onDateSelected(selectedDay);
          Navigator.pop(context);
        },
        rowHeight: _rowHeight,
        calendarFormat: CalendarFormat.month,
        eventLoader: (day) => events[DateTime(day.year, day.month, day.day)] ?? [],
        startingDayOfWeek: StartingDayOfWeek.monday,
        headerVisible: false,
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          weekendStyle: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          cellPadding: const EdgeInsets.all(0),
          cellMargin: const EdgeInsets.all(2),
          defaultTextStyle: const TextStyle(
            color: Colors.black,
            fontSize: 16, // Увеличен размер шрифта
            fontWeight: FontWeight.w400,
          ),
          outsideTextStyle: const TextStyle(
            color: Colors.grey, // Цвет для дней вне текущего месяца
            fontSize: 16, // Увеличен размер шрифта для соседних месяцев
            fontWeight: FontWeight.w400,
          ),
          weekendTextStyle: const TextStyle(
            color: Colors.black,
            fontSize: 16, // Увеличен размер шрифта
            fontWeight: FontWeight.w400,
          ),
          todayTextStyle: const TextStyle(
            color: Colors.black,
            fontSize: 16, // Увеличен размер шрифта
            fontWeight: FontWeight.w400,
          ),
          todayDecoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.black,
            fontSize: 16, // Увеличен размер шрифта
            fontWeight: FontWeight.w400,
          ),
          selectedDecoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
          ),
          defaultDecoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
          ),
          weekendDecoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
          ),
          tableBorder: TableBorder(
            horizontalInside: BorderSide(color: Colors.grey[300]!, width: 1),
            verticalInside: BorderSide(color: Colors.grey[300]!, width: 1),
            bottom: BorderSide(color: Colors.grey[300]!, width: 1), // Добавлена нижняя граница
          ),
          markersMaxCount: 0,
          isTodayHighlighted: false,
        ),
        calendarBuilders: CalendarBuilders(
          dowBuilder: (context, day) {
            final text = DateFormat.E('ru_RU').format(day).substring(0, 2).toUpperCase();
            return Center(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            );
          },
          defaultBuilder: (context, day, focusedDay) {
            final eventList = events[DateTime(day.year, day.month, day.day)] ?? [];

            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  alignment: Alignment.topCenter,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16, // Увеличен размер шрифта
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                if (eventList.isNotEmpty)
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: eventList.map((event) {
                        final mealTypeId = event['mealTypeId'] as int;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 1),
                          color: _mealTypeColors?[mealTypeId] ?? Colors.grey[300],
                          height: 20,
                          width: double.infinity,
                          child: Center(
                            child: Text(
                              event['mealTypeName'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            );
          },
          todayBuilder: (context, day, focusedDay) {
            final eventList = events[DateTime(day.year, day.month, day.day)] ?? [];

            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  alignment: Alignment.topCenter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF6200EA).withOpacity(0.3),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16, // Увеличен размер шрифта
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                if (eventList.isNotEmpty)
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: eventList.map((event) {
                        final mealTypeId = event['mealTypeId'] as int;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 1),
                          color: _mealTypeColors?[mealTypeId] ?? Colors.grey[300],
                          height: 20,
                          width: double.infinity,
                          child: Center(
                            child: Text(
                              event['mealTypeName'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            );
          },
          selectedBuilder: (context, day, focusedDay) {
            final eventList = events[DateTime(day.year, day.month, day.day)] ?? [];
            final isToday = isSameDay(day, DateTime.now());

            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  alignment: Alignment.topCenter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isToday ? const Color(0xFF6200EA).withOpacity(0.3) : Colors.transparent,
                    border: isToday ? null : Border.all(color: Colors.black, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16, // Увеличен размер шрифта
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                if (eventList.isNotEmpty)
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: eventList.map((event) {
                        final mealTypeId = event['mealTypeId'] as int;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 1),
                          color: _mealTypeColors?[mealTypeId] ?? Colors.grey[300],
                          height: 20,
                          width: double.infinity,
                          child: Center(
                            child: Text(
                              event['mealTypeName'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}