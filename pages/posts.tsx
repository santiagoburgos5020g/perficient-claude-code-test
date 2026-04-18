import { usePosts } from '@/features/posts/hooks/usePosts';
import PostList from '@/features/posts/components/PostList';
import ErrorBoundary from '@/components/ErrorBoundary/ErrorBoundary';

export default function PostsPage() {
  const { posts, isLoading, error } = usePosts();

  return (
    <ErrorBoundary>
      <main className="p-4">
        <h1 className="text-2xl font-bold mb-4">Posts</h1>

        {isLoading && (
          <p role="status" aria-busy="true" className="text-gray-500">
            Loading...
          </p>
        )}

        {error && (
          <p role="alert" className="text-red-500">Error: {error}</p>
        )}

        {!isLoading && !error && <PostList posts={posts} />}
      </main>
    </ErrorBoundary>
  );
}
