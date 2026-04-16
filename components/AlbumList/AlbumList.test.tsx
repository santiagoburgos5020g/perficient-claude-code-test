import { render, screen } from '@testing-library/react';
import AlbumList from './AlbumList';
import type { Album } from '@/types/album';

const mockAlbums: Album[] = [
  { userId: 1, id: 1, title: 'First Album' },
  { userId: 1, id: 2, title: 'Second Album' },
];

describe('AlbumList', () => {
  it('renders a list of albums', () => {
    render(<AlbumList albums={mockAlbums} />);
    expect(screen.getByRole('list')).toBeInTheDocument();
    expect(screen.getAllByRole('listitem')).toHaveLength(2);
  });

  it('displays album id and title', () => {
    render(<AlbumList albums={mockAlbums} />);
    expect(screen.getByText('1.')).toBeInTheDocument();
    expect(screen.getByText('First Album')).toBeInTheDocument();
    expect(screen.getByText('2.')).toBeInTheDocument();
    expect(screen.getByText('Second Album')).toBeInTheDocument();
  });

  it('renders empty list when no albums provided', () => {
    render(<AlbumList albums={[]} />);
    const list = screen.getByRole('list');
    expect(list.children).toHaveLength(0);
  });
});
