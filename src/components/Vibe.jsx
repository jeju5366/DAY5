import './Vibe.css'

function Vibe({ emoji, title, category, description, tags = [], color }) {
  return (
    <article className="vibe" style={{ '--vibe-color': color }}>
      <div className="vibe-thumb" aria-hidden="true">
        {emoji}
      </div>
      <div className="vibe-body">
        <span className="vibe-category">{category}</span>
        <h2 className="vibe-title">{title}</h2>
        <p className="vibe-desc">{description}</p>
        <ul className="vibe-tags">
          {tags.map((tag) => (
            <li key={tag}>#{tag}</li>
          ))}
        </ul>
      </div>
    </article>
  )
}

export default Vibe
