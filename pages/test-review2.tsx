import { usePosts } from '@/features/posts/hooks/usePosts';
import PostList from '@/features/posts/components/PostList';

export default function TestReview2Page() {
  const { posts, isLoading, error } = usePosts();

  return (
    <main className="bg-white min-h-screen w-full p-8">
      <h1 className="text-2xl font-bold text-perficient-dark mb-6">Posts</h1>

      {isLoading && (
        <p className="text-gray-500" role="status" aria-busy="true">Loading posts...</p>
      )}

      {error && (
        <p className="text-red-600" role="alert">Error: {error}</p>
      )}

      {!isLoading && !error && <PostList posts={posts} />}
    </main>
  );
}
