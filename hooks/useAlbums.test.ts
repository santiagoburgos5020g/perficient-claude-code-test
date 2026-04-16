import { renderHook, waitFor } from '@testing-library/react';
import { useAlbums } from './useAlbums';
import useSWR from 'swr';

jest.mock('swr');
const mockUseSWR = useSWR as jest.MockedFunction<typeof useSWR>;

describe('useAlbums', () => {
  it('returns loading state initially', () => {
    mockUseSWR.mockReturnValue({
      data: undefined,
      error: undefined,
      isLoading: true,
      isValidating: false,
      mutate: jest.fn(),
    });

    const { result } = renderHook(() => useAlbums());
    expect(result.current.isLoading).toBe(true);
    expect(result.current.albums).toEqual([]);
    expect(result.current.error).toBeNull();
  });

  it('returns albums when data is loaded', () => {
    const albums = [{ userId: 1, id: 1, title: 'Test Album' }];
    mockUseSWR.mockReturnValue({
      data: albums,
      error: undefined,
      isLoading: false,
      isValidating: false,
      mutate: jest.fn(),
    });

    const { result } = renderHook(() => useAlbums());
    expect(result.current.isLoading).toBe(false);
    expect(result.current.albums).toEqual(albums);
    expect(result.current.error).toBeNull();
  });

  it('returns error message on failure', () => {
    mockUseSWR.mockReturnValue({
      data: undefined,
      error: new Error('Network error'),
      isLoading: false,
      isValidating: false,
      mutate: jest.fn(),
    });

    const { result } = renderHook(() => useAlbums());
    expect(result.current.error).toBe('Network error');
    expect(result.current.albums).toEqual([]);
  });

  it('calls useSWR with correct URL', () => {
    mockUseSWR.mockReturnValue({
      data: undefined,
      error: undefined,
      isLoading: true,
      isValidating: false,
      mutate: jest.fn(),
    });

    renderHook(() => useAlbums());
    expect(mockUseSWR).toHaveBeenCalledWith(
      'https://jsonplaceholder.typicode.com/albums'
    );
  });
});
