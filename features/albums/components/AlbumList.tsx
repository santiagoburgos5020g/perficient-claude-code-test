import type { Album } from '@/features/albums/types/album';

interface AlbumListProps {
  albums: Album[];
}

export default function AlbumList({ albums }: AlbumListProps) {
  return (
    <ul className="space-y-2">
      {albums.map((album) => (
        <li key={album.id} className="border-b border-gray-200 pb-2">
          <span className="font-semibold text-gray-700">{album.id}.</span>{' '}
          {album.title}
        </li>
      ))}
    </ul>
  );
}
