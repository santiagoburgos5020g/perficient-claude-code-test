import type { Post } from '@/types/post';

interface PostListProps {
  posts: Post[];
}

export default function PostList({ posts }: PostListProps) {
  return (
    <ul className="space-y-4">
      {posts.map((post) => (
        <li key={post.id}>
          <article className="border border-gray-200 rounded p-4">
            <h2 className="font-bold text-perficient-dark">{post.title}</h2>
            <p className="text-sm text-perficient-dark/70">{post.body}</p>
          </article>
        </li>
      ))}
    </ul>
  );
}
