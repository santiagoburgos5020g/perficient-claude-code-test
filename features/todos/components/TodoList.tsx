import type { Todo } from '@/features/todos/types/todo';

interface TodoListProps {
  todos: Todo[];
}

export default function TodoList({ todos }: TodoListProps) {
  return (
    <ul className="space-y-2">
      {todos.map((todo) => (
        <li key={todo.id} className="flex items-center gap-2">
          <span className={todo.completed ? 'line-through text-gray-400' : 'text-gray-800'}>
            {todo.id}. {todo.title}
          </span>
          {todo.completed && <span className="text-green-600 text-sm">done</span>}
        </li>
      ))}
    </ul>
  );
}
