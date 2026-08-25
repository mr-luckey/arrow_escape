/// Sequential failover across ad unit IDs for a single placement.
///
/// Starts at the last unit that filled. Only advances on load failure.
/// After a full pass with no fill, [exhausted] is true until [beginLoad].
class AdWaterfall {
  AdWaterfall(this.ids);

  final List<String> ids;
  int _sticky = 0;
  int _offset = 0;
  bool _inPass = false;

  bool get isEmpty => ids.isEmpty;

  void beginLoad() {
    _offset = 0;
    _inPass = true;
  }

  /// Next unit in this pass, or null if every ID was already tried.
  String? next() {
    if (ids.isEmpty || !_inPass || _offset >= ids.length) return null;
    final id = ids[(_sticky + _offset) % ids.length];
    _offset++;
    return id;
  }

  void markFilled(String unitId) {
    final i = ids.indexOf(unitId);
    if (i >= 0) _sticky = i;
    _inPass = false;
  }

  bool get exhausted => ids.isEmpty || (_inPass && _offset >= ids.length);
}
