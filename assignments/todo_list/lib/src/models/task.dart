/// A to-do item. A new task is "to do" ([done] false) and not important.
class Task {
  Task({required this.title, this.important = false, this.done = false});

  final String title;
  final bool important;
  bool done;
}
