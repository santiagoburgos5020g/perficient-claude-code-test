import type { Todo } from '@/features/todos/types/todo';

interface TodoListProps {
  todos: Todo[];
}

export default function TodoList({ todos }: TodoListProps) {
  return (
    <ul className="space-y-2" role="list" aria-label="Todo items">
      {todos.map((todo) => (
        <li
          key={todo.id}
          className="flex items-center gap-3 p-3 border border-gray-200 rounded"
        >
          <span
            className={`w-3 h-3 rounded-full ${todo.completed ? 'bg-green-500' : 'bg-red-400'}`}
            aria-hidden="true"
          />
          <span className={todo.completed ? 'line-through text-gray-400' : 'text-gray-800'}>
            {todo.title}
          </span>
        </li>
      ))}
    </ul>
  );
}
