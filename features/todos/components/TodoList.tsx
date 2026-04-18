import type { Todo } from '@/features/todos/types/todo';

interface TodoListProps {
  todos: Todo[];
}

export default function TodoList({ todos }: TodoListProps) {
  return (
    <ul className="space-y-2">
      {todos.map((todo) => (
        <li key={todo.id} className="flex items-center gap-2">
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={todo.completed}
              readOnly
            />
            <span className={todo.completed ? 'line-through text-gray-400' : ''}>
              {todo.title}
            </span>
          </label>
        </li>
      ))}
    </ul>
  );
}
