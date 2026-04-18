import { useEffect, useState } from 'react';

interface Post {
  userId: number;
  id: number;
  title: string;
  body: string;
}

export default function PostsPage() {
  const [posts, setPosts] = useState<Post[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch('https://jsonplaceholder.typicode.com/posts')
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then((data: Post[]) => {
        setPosts(data);
        setIsLoading(false);
      })
      .catch((err: Error) => {
        setError(err.message);
        setIsLoading(false);
      });
  }, []);

  return (
    <main className="p-4">
      <h1 className="text-2xl font-bold mb-4">Posts</h1>

      {isLoading && (
        <p role="status" className="text-gray-500">Loading...</p>
      )}

      {error && (
        <p role="alert" className="text-red-500">Error: {error}</p>
      )}

      {!isLoading && !error && (
        <ul className="space-y-4">
          {posts.map((post) => (
            <li key={post.id} className="rounded border border-gray-200 p-4">
              <h2 className="text-lg font-semibold">{post.title}</h2>
              <p className="mt-1 text-gray-600">{post.body}</p>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
