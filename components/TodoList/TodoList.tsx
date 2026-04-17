import type { Todo } from '@/types/todo';

interface TodoListProps {
  todos: Todo[];
}

export default function TodoList({ todos }: TodoListProps) {
  return (
    <ul className="space-y-2">
      {todos.map((todo) => (
        <li key={todo.id} className="flex items-center gap-2 p-2 border rounded">
          <input
            type="checkbox"
            checked={todo.completed}
            readOnly
            id={`todo-${todo.id}`}
            className="h-4 w-4"
          />
          <label
            htmlFor={`todo-${todo.id}`}
            className={todo.completed ? 'line-through text-gray-400' : 'text-gray-800'}
          >
            {todo.title}
          </label>
        </li>
      ))}
    </ul>
  );
}
