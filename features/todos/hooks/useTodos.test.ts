import { renderHook, waitFor } from '@testing-library/react';
import { SWRConfig } from 'swr';
import { useTodos } from './useTodos';
import type { ReactNode } from 'react';
import React from 'react';

const originalFetch = global.fetch;

function createWrapper() {
  return function Wrapper({ children }: { children: ReactNode }) {
    return React.createElement(
      SWRConfig,
      {
        value: {
          fetcher: (url: string) => global.fetch(url).then((r: Response) => {
            if (!r.ok) throw new Error(`Fetch error: ${r.status}`);
            return r.json();
          }),
          provider: () => new Map(),
          dedupingInterval: 0,
        },
      },
      children
    );
  };
}

describe('useTodos', () => {
  afterEach(() => {
    global.fetch = originalFetch;
  });

  it('returns loading state initially', async () => {
    global.fetch = jest.fn(() => new Promise(() => {})) as jest.Mock;
    const { result } = renderHook(() => useTodos(), { wrapper: createWrapper() });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(true);
    });
    expect(result.current.todos).toEqual([]);
    expect(result.current.error).toBeNull();
  });

  it('returns todos on successful fetch', async () => {
    const mockTodos = [{ userId: 1, id: 1, title: 'Test', completed: false }];
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ todos: mockTodos }),
    }) as jest.Mock;

    const { result } = renderHook(() => useTodos(), { wrapper: createWrapper() });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(result.current.todos).toEqual(mockTodos);
    expect(result.current.error).toBeNull();
  });

  it('returns error message on fetch failure', async () => {
    global.fetch = jest.fn().mockRejectedValue(new Error('Network error')) as jest.Mock;

    const { result } = renderHook(() => useTodos(), { wrapper: createWrapper() });

    await waitFor(() => {
      expect(result.current.error).not.toBeNull();
    });

    expect(result.current.todos).toEqual([]);
  });

  it('defaults todos to empty array when data is undefined', async () => {
    global.fetch = jest.fn(() => new Promise(() => {})) as jest.Mock;
    const { result } = renderHook(() => useTodos(), { wrapper: createWrapper() });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(true);
    });
    expect(result.current.todos).toEqual([]);
  });
});
