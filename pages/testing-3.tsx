import { useState, useEffect } from 'react';

interface Album {
  userId: number;
  id: number;
  title: string;
}

export default function Testing3Page() {
  const [albums, setAlbums] = useState<Album[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch('https://jsonplaceholder.typicode.com/albums')
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then((data: Album[]) => {
        setAlbums(data);
        setLoading(false);
      })
      .catch((err: Error) => {
        setError(err.message);
        setLoading(false);
      });
  }, []);

  return (
    <main className="bg-white min-h-screen w-full p-8">
      <h1 className="text-2xl font-bold text-perficient-dark mb-6">Albums</h1>

      {loading && <p>Loading albums...</p>}
      {error && <p className="text-red-600">Error: {error}</p>}

      {!loading && !error && (
        <ul className="space-y-2">
          {albums.map((album) => (
            <li key={album.id} className="border-b border-gray-200 pb-2">
              <span className="font-semibold text-gray-700">{album.id}.</span>{' '}
              {album.title}
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
