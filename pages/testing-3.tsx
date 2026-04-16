import { useAlbums } from '@/features/albums/hooks/useAlbums';
import AlbumList from '@/features/albums/components/AlbumList';

export default function AlbumsPage() {
  const { albums, isLoading, error } = useAlbums();

  return (
    <main className="bg-white min-h-screen w-full p-8">
      <h1 className="text-2xl font-bold text-perficient-dark mb-6">Albums</h1>

      {isLoading && (
        <p className="text-gray-500" role="status" aria-busy="true">Loading albums...</p>
      )}

      {error && (
        <p className="text-red-600" role="alert">Error: {error}</p>
      )}

      {!isLoading && !error && <AlbumList albums={albums} />}
    </main>
  );
}
