import Vibe from './components/Vibe'
import './App.css'

const vibes = [
  {
    emoji: '🌋',
    category: '자연',
    title: '한라산',
    description: '해발 1,947m, 대한민국에서 가장 높은 산. 사계절 다른 풍경의 트레킹 명소.',
    tags: ['등산', '백록담', '유네스코'],
    color: '#a5d6a7',
  },
  {
    emoji: '🌅',
    category: '자연',
    title: '성산일출봉',
    description: '바다 위에 솟은 분화구에서 맞이하는 제주 최고의 일출.',
    tags: ['일출', '화산', '세계유산'],
    color: '#ffcc80',
  },
  {
    emoji: '🏖️',
    category: '바다',
    title: '협재해수욕장',
    description: '에메랄드빛 바다와 하얀 모래, 멀리 비양도가 보이는 서쪽 해변.',
    tags: ['해변', '에메랄드', '서쪽'],
    color: '#81d4fa',
  },
  {
    emoji: '🌊',
    category: '자연',
    title: '천지연폭포',
    description: '울창한 숲 사이로 떨어지는 폭포, 밤에는 조명이 더해져 더 아름다워요.',
    tags: ['폭포', '서귀포', '야경'],
    color: '#80cbc4',
  },
  {
    emoji: '🍊',
    category: '먹거리',
    title: '감귤 체험',
    description: '제주 감귤밭에서 직접 따 먹는 상큼한 체험. 겨울이 제철이에요.',
    tags: ['감귤', '체험', '가족여행'],
    color: '#ffb74d',
  },
  {
    emoji: '🐷',
    category: '먹거리',
    title: '흑돼지 거리',
    description: '쫄깃한 제주 흑돼지 구이를 맛볼 수 있는 대표 맛집 거리.',
    tags: ['흑돼지', '맛집', '제주시'],
    color: '#ef9a9a',
  },
  {
    emoji: '🐴',
    category: '체험',
    title: '승마 & 목장',
    description: '초원 위에서 조랑말과 함께하는 여유로운 승마 체험.',
    tags: ['조랑말', '승마', '초원'],
    color: '#bcaaa4',
  },
  {
    emoji: '🌸',
    category: '계절',
    title: '유채꽃 · 벚꽃 시즌',
    description: '봄이면 노란 유채꽃과 벚꽃이 섬 전체를 물들여요.',
    tags: ['봄', '유채꽃', '벚꽃길'],
    color: '#f8bbd0',
  },
  {
    emoji: '🚗',
    category: '드라이브',
    title: '해안도로 드라이브',
    description: '바다를 끼고 달리는 애월 해안도로, 감성 카페가 줄지어 있어요.',
    tags: ['애월', '카페', '드라이브'],
    color: '#b39ddb',
  },
  {
    emoji: '🏡',
    category: '숙소',
    title: '돌담 감성 숙소',
    description: '제주 전통 돌담과 현대적 감각이 어우러진 힐링 스테이.',
    tags: ['스테이', '돌담', '힐링'],
    color: '#c5e1a5',
  },
]

function App() {
  return (
    <main className="app">
      <header className="hero">
        <h1>🌴 제주도 여행 가이드</h1>
        <p>자연, 맛, 바다, 감성까지. 제주의 매력 10곳을 소개합니다.</p>
      </header>

      <section className="vibe-grid">
        {vibes.map((vibe) => (
          <Vibe key={vibe.title} {...vibe} />
        ))}
      </section>
    </main>
  )
}

export default App
