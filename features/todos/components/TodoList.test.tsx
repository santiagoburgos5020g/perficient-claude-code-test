import { render, screen } from '@testing-library/react';
import TodoList from './TodoList';
import type { Todo } from '@/features/todos/types/todo';

const mockTodos: Todo[] = [
  { userId: 1, id: 1, title: 'Buy groceries', completed: false },
  { userId: 1, id: 2, title: 'Walk the dog', completed: true },
];

describe('TodoList', () => {
  it('renders all todo items', () => {
    render(<TodoList todos={mockTodos} />);
    expect(screen.getByText('Buy groceries')).toBeInTheDocument();
    expect(screen.getByText('Walk the dog')).toBeInTheDocument();
  });

  it('renders disabled checkboxes with explicit label associations', () => {
    render(<TodoList todos={mockTodos} />);
    const checkbox1 = screen.getByLabelText('Buy groceries');
    const checkbox2 = screen.getByLabelText('Walk the dog');
    expect(checkbox1).not.toBeChecked();
    expect(checkbox2).toBeChecked();
    expect(checkbox1).toBeDisabled();
    expect(checkbox2).toBeDisabled();
  });

  it('applies line-through styling to completed todos', () => {
    render(<TodoList todos={mockTodos} />);
    const completedText = screen.getByText('Walk the dog');
    expect(completedText).toHaveClass('line-through', 'text-gray-400');
  });

  it('does not apply line-through styling to incomplete todos', () => {
    render(<TodoList todos={mockTodos} />);
    const incompleteText = screen.getByText('Buy groceries');
    expect(incompleteText).not.toHaveClass('line-through');
  });

  it('renders an empty list when no todos are provided', () => {
    render(<TodoList todos={[]} />);
    const list = screen.getByRole('list');
    expect(list).toBeInTheDocument();
    expect(screen.queryAllByRole('listitem')).toHaveLength(0);
  });
});
