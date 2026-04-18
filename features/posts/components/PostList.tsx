import type { Post } from '@/features/posts/types/post';

interface PostListProps {
  posts: Post[];
}

export default function PostList({ posts }: PostListProps) {
  return (
    <ul className="space-y-4">
      {posts.map((post) => (
        <li key={post.id} className="rounded border border-gray-200 p-4">
          <h2 className="text-lg font-semibold">{post.title}</h2>
          <p className="mt-1 text-gray-600">{post.body}</p>
        </li>
      ))}
    </ul>
  );
}
