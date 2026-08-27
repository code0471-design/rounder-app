class GolfCourse {
  final String name;
  final String address;

  const GolfCourse({required this.name, required this.address});
}

/// 일정 등록 자동완성용 국내 골프장 목록 (이름 검색 → 주소 채움).
const List<GolfCourse> kKoreanGolfCourses = [
  GolfCourse(name: '레이크사이드CC', address: '경기도 용인시 처인구 남사읍 봉무로 157'),
  GolfCourse(name: '남서울CC', address: '경기도 성남시 분당구 구미동'),
  GolfCourse(name: '안양베네스트GC', address: '경기도 군포시 속달동'),
  GolfCourse(name: '우정힐스CC', address: '충청남도 천안시 서북구 입장면'),
  GolfCourse(name: '스카이72 오션', address: '인천광역시 중구 운서동 영종하늘도시'),
  GolfCourse(name: '스카이72 하늘', address: '인천광역시 중구 운서동 영종하늘도시'),
  GolfCourse(name: '스카이72 클래식', address: '인천광역시 중구 운서동 영종하늘도시'),
  GolfCourse(name: '스카이72 킹', address: '인천광역시 중구 운서동 영종하늘도시'),
  GolfCourse(name: '잭니클라우스GC 코리아', address: '인천광역시 서구 왕길동'),
  GolfCourse(name: '베어크리크GC', address: '인천광역시 서구 경서동'),
  GolfCourse(name: '베어크리크 일산', address: '경기도 고양시 일산서구'),
  GolfCourse(name: '가평베네스트GC', address: '경기도 가평군 설악면'),
  GolfCourse(name: '자유CC', address: '경기도 여주시 가남읍'),
  GolfCourse(name: '여주CC', address: '경기도 여주시'),
  GolfCourse(name: '여주신라CC', address: '경기도 여주시 대신면'),
  GolfCourse(name: '이천마이다스CC', address: '경기도 이천시 마장면'),
  GolfCourse(name: '이천CC', address: '경기도 이천시'),
  GolfCourse(name: '블랙스톤이천', address: '경기도 이천시 모가면'),
  GolfCourse(name: '사우스스프링스CC', address: '경기도 이천시 모가면'),
  GolfCourse(name: '썬밸리CC', address: '강원특별자치도 원주시 지정면'),
  GolfCourse(name: '오크밸리CC', address: '강원특별자치도 원주시 지정면'),
  GolfCourse(name: '오크힐스CC', address: '강원특별자치도 원주시'),
  GolfCourse(name: '용인CC', address: '경기도 용인시 처인구'),
  GolfCourse(name: '88CC', address: '경기도 용인시 기흥구'),
  GolfCourse(name: '태광CC', address: '경기도 용인시 처인구'),
  GolfCourse(name: '수원CC', address: '경기도 수원시 영통구'),
  GolfCourse(name: '기흥CC', address: '경기도 용인시 기흥구'),
  GolfCourse(name: '한원CC', address: '경기도 용인시 처인구'),
  GolfCourse(name: '에덴블루CC', address: '경기도 용인시 처인구'),
  GolfCourse(name: '골드CC', address: '경기도 용인시'),
  GolfCourse(name: '포레스트힐CC', address: '경기도 광주시'),
  GolfCourse(name: '양지파인CC', address: '경기도 용인시 처인구 양지면'),
  GolfCourse(name: '써클비CC', address: '경기도 용인시'),
  GolfCourse(name: '발리오스CC', address: '경기도 용인시 처인구'),
  GolfCourse(name: '블루헤런CC', address: '경기도 여주시'),
  GolfCourse(name: '비에이비스타CC', address: '경기도 이천시'),
  GolfCourse(name: '크리스탈밸리CC', address: '경기도 이천시'),
  GolfCourse(name: '뉴코리아CC', address: '경기도 김포시'),
  GolfCourse(name: '김포CC', address: '경기도 김포시'),
  GolfCourse(name: '파인리즈CC', address: '경기도 파주시'),
  GolfCourse(name: '서원밸리CC', address: '경기도 파주시 광탄면'),
  GolfCourse(name: '파주CC', address: '경기도 파주시'),
  GolfCourse(name: '한양CC', address: '경기도 고양시'),
  GolfCourse(name: '신원CC', address: '경기도 고양시'),
  GolfCourse(name: '푸른솔포천CC', address: '경기도 포천시'),
  GolfCourse(name: '포천힐스CC', address: '경기도 포천시'),
  GolfCourse(name: '몽베르CC', address: '경기도 포천시'),
  GolfCourse(name: '비에이비스타 포천', address: '경기도 포천시'),
  GolfCourse(name: '솔모로CC', address: '경기도 포천시'),
  GolfCourse(name: '아리지CC', address: '경기도 가평군'),
  GolfCourse(name: '가평CC', address: '경기도 가평군'),
  GolfCourse(name: '북악CC', address: '서울특별시 종로구'),
  GolfCourse(name: '서울CC', address: '서울특별시 강남구 개포동'),
  GolfCourse(name: '한강CC', address: '경기도 하남시'),
  GolfCourse(name: '남부CC', address: '경기도 광주시'),
  GolfCourse(name: '중부CC', address: '경기도 광주시'),
  GolfCourse(name: '태평양CC', address: '경기도 광주시'),
  GolfCourse(name: '양평TPC', address: '경기도 양평군'),
  GolfCourse(name: '양평TPC 블랙', address: '경기도 양평군'),
  GolfCourse(name: '더스타휴CC', address: '경기도 양평군'),
  GolfCourse(name: '사조CC', address: '경기도 양평군'),
  GolfCourse(name: '블랙스톤여주', address: '경기도 여주시'),
  GolfCourse(name: '마스타CC', address: '경기도 여주시'),
  GolfCourse(name: '페럼CC', address: '경기도 여주시'),
  GolfCourse(name: '라싸CC', address: '경기도 여주시'),
  GolfCourse(name: '블루원용인', address: '경기도 용인시'),
  GolfCourse(name: '블루원상주', address: '경상북도 상주시'),
  GolfCourse(name: '블루원리조트 천안', address: '충청남도 천안시'),
  GolfCourse(name: '파가니카CC', address: '충청남도 천안시'),
  GolfCourse(name: '도고CC', address: '충청남도 아산시 도고면'),
  GolfCourse(name: '아산CC', address: '충청남도 아산시'),
  GolfCourse(name: '솔라고CC', address: '충청남도 태안군'),
  GolfCourse(name: '대천CC', address: '충청남도 보령시'),
  GolfCourse(name: '태안CC', address: '충청남도 태안군'),
  GolfCourse(name: '서산CC', address: '충청남도 서산시'),
  GolfCourse(name: '청주CC', address: '충청북도 청주시'),
  GolfCourse(name: '청풍레이크CC', address: '충청북도 제천시'),
  GolfCourse(name: '오창CC', address: '충청북도 청주시 청원구'),
  GolfCourse(name: '진천CC', address: '충청북도 진천군'),
  GolfCourse(name: '충주호CC', address: '충청북도 충주시'),
  GolfCourse(name: '스프링데일CC', address: '충청북도 음성군'),
  GolfCourse(name: '센추리21CC', address: '충청북도 음성군'),
  GolfCourse(name: '세븐밸리CC', address: '충청남도 공주시'),
  GolfCourse(name: '금강CC', address: '충청남도 공주시'),
  GolfCourse(name: '계룡CC', address: '충청남도 계룡시'),
  GolfCourse(name: '대전CC', address: '대전광역시'),
  GolfCourse(name: '유성CC', address: '대전광역시 유성구'),
  GolfCourse(name: '골든비치CC', address: '강원특별자치도 고성군'),
  GolfCourse(name: '설해원CC', address: '강원특별자치도 고성군'),
  GolfCourse(name: '파인리즈CC 강원', address: '강원특별자치도 원주시'),
  GolfCourse(name: '블랙밸리CC', address: '강원특별자치도 춘천시'),
  GolfCourse(name: '라데나GC', address: '강원특별자치도 춘천시'),
  GolfCourse(name: '엘리시안강촌CC', address: '강원특별자치도 춘천시'),
  GolfCourse(name: '비발디파크CC', address: '강원특별자치도 홍천군'),
  GolfCourse(name: '오크밸리 성문안', address: '강원특별자치도 원주시'),
  GolfCourse(name: '알펜시아CC', address: '강원특별자치도 평창군'),
  GolfCourse(name: '용평GC', address: '강원특별자치도 평창군'),
  GolfCourse(name: '버치힐GC', address: '강원특별자치도 평창군'),
  GolfCourse(name: '하이원리조트CC', address: '강원특별자치도 정선군'),
  GolfCourse(name: '동래베네스트GC', address: '부산광역시 금정구'),
  GolfCourse(name: '아시아드CC', address: '부산광역시 기장군'),
  GolfCourse(name: '해운대CC', address: '부산광역시 기장군'),
  GolfCourse(name: '동부산CC', address: '부산광역시 기장군'),
  GolfCourse(name: '기장CC', address: '부산광역시 기장군'),
  GolfCourse(name: '센텀CC', address: '부산광역시'),
  GolfCourse(name: '부산CC', address: '부산광역시'),
  GolfCourse(name: '베어즈베스트 청라', address: '인천광역시 서구 청라동'),
  GolfCourse(name: '스카이72', address: '인천광역시 중구 운서동'),
  GolfCourse(name: '클럽72', address: '인천광역시 중구 운서동'),
  GolfCourse(name: '인천CC', address: '인천광역시'),
  GolfCourse(name: '송도CC', address: '인천광역시 연수구'),
  GolfCourse(name: '실크리버CC', address: '인천광역시'),
  GolfCourse(name: '실크리버CC 여주', address: '경기도 여주시'),
  GolfCourse(name: '화산CC', address: '경기도 수원시 권선구'),
  GolfCourse(name: '서서울CC', address: '경기도 파주시'),
  GolfCourse(name: '뉴서울CC', address: '경기도 광주'),
  GolfCourse(name: '한라CC', address: '제주특별자치도 제주시'),
  GolfCourse(name: '핀크스GC', address: '제주특별자치도 서귀포시 안덕면'),
  GolfCourse(name: '나인브릿지', address: '제주특별자치도 서귀포시 서호동'),
  GolfCourse(name: '엘리시안CC 제주', address: '제주특별자치도 서귀포시'),
  GolfCourse(name: '해비치CC 제주', address: '제주특별자치도 서귀포시 표선면'),
  GolfCourse(name: '사이프러스CC', address: '제주특별자치도 서귀포시'),
  GolfCourse(name: '블랙스톤제주', address: '제주특별자치도 서귀포시'),
  GolfCourse(name: '에딘버러CC', address: '제주특별자치도 제주시'),
  GolfCourse(name: '세인트포CC', address: '제주특별자치도 제주시'),
  GolfCourse(name: '크라운CC', address: '제주특별자치도 제주시'),
  GolfCourse(name: '라온GC', address: '제주특별자치도 제주시'),
  GolfCourse(name: '부영CC', address: '제주특별자치도 서귀포시'),
  GolfCourse(name: '중문GC', address: '제주특별자치도 서귀포시 중문동'),
  GolfCourse(name: '롯데스카이힐 제주', address: '제주특별자치도 서귀포시'),
  GolfCourse(name: '롯데스카이힐 김해', address: '경상남도 김해시'),
  GolfCourse(name: '롯데스카이힐 부여', address: '충청남도 부여군'),
  GolfCourse(name: '김해CC', address: '경상남도 김해시'),
  GolfCourse(name: '양산CC', address: '경상남도 양산시'),
  GolfCourse(name: '동부산CC', address: '부산광역시 기장군'),
  GolfCourse(name: '통도CC', address: '경상남도 양산시'),
  GolfCourse(name: '울산CC', address: '울산광역시'),
  GolfCourse(name: '경주CC', address: '경상북도 경주시'),
  GolfCourse(name: '보문CC', address: '경상북도 경주시'),
  GolfCourse(name: '대구CC', address: '대구광역시'),
  GolfCourse(name: '팔공산CC', address: '대구광역시 동구'),
  GolfCourse(name: '가창CC', address: '대구광역시 달성군'),
  GolfCourse(name: '스톤게이트CC', address: '경상북도 경산시'),
  GolfCourse(name: '포항CC', address: '경상북도 포항시'),
  GolfCourse(name: '안동CC', address: '경상북도 안동시'),
  GolfCourse(name: '문경CC', address: '경상북도 문경시'),
  GolfCourse(name: '구미CC', address: '경상북도 구미시'),
  GolfCourse(name: '창원CC', address: '경상남도 창원시'),
  GolfCourse(name: '거제CC', address: '경상남도 거제시'),
  GolfCourse(name: '통영CC', address: '경상남도 통영시'),
  GolfCourse(name: '사천CC', address: '경상남도 사천시'),
  GolfCourse(name: '진주CC', address: '경상남도 진주시'),
  GolfCourse(name: '남해CC', address: '경상남도 남해군'),
  GolfCourse(name: '광주CC', address: '광주광역시'),
  GolfCourse(name: '호남권CC', address: '전라남도 담양군'),
  GolfCourse(name: '담양CC', address: '전라남도 담양군'),
  GolfCourse(name: '여수CC', address: '전라남도 여수시'),
  GolfCourse(name: '순천CC', address: '전라남도 순천시'),
  GolfCourse(name: '남중CC', address: '전북특별자치도 남원시'),
  GolfCourse(name: '무주CC', address: '전북특별자치도 무주군'),
  GolfCourse(name: '전주CC', address: '전북특별자치도 전주시'),
  GolfCourse(name: '익산CC', address: '전북특별자치도 익산시'),
  GolfCourse(name: '군산CC', address: '전북특별자치도 군산시'),
  GolfCourse(name: '고창CC', address: '전북특별자치도 고창군'),
  GolfCourse(name: '휘닉스파크CC', address: '강원특별자치도 평창군'),
  GolfCourse(name: '용인 실크밸리CC', address: '경기도 용인시'),
  GolfCourse(name: '에이치스위트CC', address: '경기도 이천시'),
  GolfCourse(name: '렉스필드CC', address: '경기도 여주시'),
  GolfCourse(name: '발리오스CC 여주', address: '경기도 여주시'),
  GolfCourse(name: '이스트밸리CC', address: '경기도 이천시'),
  GolfCourse(name: '리베라CC', address: '경기도 광주'),
  GolfCourse(name: '한성CC', address: '경기도 용인시'),
  GolfCourse(name: '기흥CC 남성대', address: '경기도 용인시 기흥구'),
];

List<GolfCourse> searchGolfCourses(
  String query, {
  List<GolfCourse> extras = const [],
}) {
  final q = query.trim().toLowerCase().replaceAll(' ', '');
  if (q.isEmpty) return const [];

  final seen = <String>{};
  final hits = <GolfCourse>[];

  void consider(GolfCourse course) {
    final key = course.name.replaceAll(' ', '').toLowerCase();
    if (!seen.add(key)) return;
    final name = course.name.toLowerCase().replaceAll(' ', '');
    if (name.contains(q)) hits.add(course);
  }

  for (final c in extras) {
    consider(c);
  }
  for (final c in kKoreanGolfCourses) {
    consider(c);
  }
  if (hits.length > 12) return hits.sublist(0, 12);
  return hits;
}

List<GolfCourse> golfCoursesFromSchedules(Iterable<dynamic> schedules) {
  final out = <GolfCourse>[];
  final seen = <String>{};
  for (final s in schedules) {
    final name = (s.courseName as String?)?.trim() ?? '';
    if (name.isEmpty) continue;
    final key = name.replaceAll(' ', '').toLowerCase();
    if (!seen.add(key)) continue;
    final address = (s.courseAddress as String?)?.trim() ?? '';
    out.add(GolfCourse(name: name, address: address));
  }
  return out;
}
