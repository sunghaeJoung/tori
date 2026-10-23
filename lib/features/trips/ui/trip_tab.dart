/// 여행방의 탭. 주소의 `?tab=`으로 고를 수 있다 (예: 정산을 확정한 뒤 정산 탭으로).
enum TripTab {
  expenses('지출'),
  balances('잔액'),
  settle('정산');

  const TripTab(this.label);

  final String label;
}
