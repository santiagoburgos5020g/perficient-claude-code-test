import { render, screen } from '@testing-library/react';
import TodosPage from './todos';
import { useTodos } from '@/features/todos/hooks/useTodos';

jest.mock('@/features/todos/hooks/useTodos');

const mockUseTodos = useTodos as jest.MockedFunction<typeof useTodos>;

function createMockReturn(overrides: Partial<ReturnType<typeof useTodos>> = {}) {
  return {
    todos: [],
    isLoading: false,
    error: null,
    mutate: jest.fn(),
    ...overrides,
  };
}

describe('TodosPage', () => {
  it('shows loading status when loading', () => {
    mockUseTodos.mockReturnValue(createMockReturn({ isLoading: true }));
    render(<TodosPage />);
    expect(screen.getByRole('status')).toBeInTheDocument();
    expect(screen.getByRole('status')).toHaveTextContent('Loading...');
  });

  it('shows error alert when error occurs', () => {
    mockUseTodos.mockReturnValue(createMockReturn({ error: 'Something went wrong' }));
    render(<TodosPage />);
    expect(screen.getByRole('alert')).toBeInTheDocument();
    expect(screen.getByRole('alert')).toHaveTextContent('Error: Something went wrong');
  });

  it('renders todo list on successful load', () => {
    mockUseTodos.mockReturnValue(
      createMockReturn({
        todos: [
          { userId: 1, id: 1, title: 'Test todo', completed: false },
        ],
      })
    );
    render(<TodosPage />);
    expect(screen.getByText('Test todo')).toBeInTheDocument();
  });

  it('does not show loading or error when data is loaded', () => {
    mockUseTodos.mockReturnValue(
      createMockReturn({
        todos: [{ userId: 1, id: 1, title: 'Test', completed: true }],
      })
    );
    render(<TodosPage />);
    expect(screen.queryByRole('status')).not.toBeInTheDocument();
    expect(screen.queryByRole('alert')).not.toBeInTheDocument();
  });

  it('renders page heading', () => {
    mockUseTodos.mockReturnValue(createMockReturn());
    render(<TodosPage />);
    expect(screen.getByRole('heading', { name: 'Todos' })).toBeInTheDocument();
  });
});
