import type { Todo } from '@/features/todos/types/todo';

interface TodoListProps {
  todos: Todo[];
}

export default function TodoList({ todos }: TodoListProps) {
  return (
    <ul className="space-y-2">
      {todos.map((todo) => (
        <li key={todo.id}>
          <label className="flex items-center gap-2 p-2 border rounded cursor-default">
            <input
              type="checkbox"
              checked={todo.completed}
              readOnly
              aria-readonly="true"
            />
            <span className={todo.completed ? 'line-through text-gray-400' : 'text-gray-800'}>
              {todo.title}
            </span>
          </label>
        </li>
      ))}
    </ul>
  );
}
