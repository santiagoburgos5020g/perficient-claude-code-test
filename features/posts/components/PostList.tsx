import type { Post } from '@/features/posts/types/post';

interface PostListProps {
  posts: Post[];
}

export default function PostList({ posts }: PostListProps) {
  return (
    <ul className="space-y-4">
      {posts.map((post) => (
        <li
          key={post.id}
          className="border border-gray-200 rounded p-4"
        >
          <h3 className="font-bold text-perficient-dark">{post.title}</h3>
          <p className="text-sm text-perficient-dark/70">{post.body}</p>
        </li>
      ))}
    </ul>
  );
}
