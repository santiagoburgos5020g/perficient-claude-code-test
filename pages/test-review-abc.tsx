import { useEffect, useState } from 'react';

interface Todo {
  userId: number;
  id: number;
  title: string;
  completed: boolean;
}

export default function TestReviewAbcPage() {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch('https://jsonplaceholder.typicode.com/todos')
      .then((res) => {
        if (!res.ok) throw new Error('Failed to fetch todos');
        return res.json();
      })
      .then((data) => {
        setTodos(data);
        setIsLoading(false);
      })
      .catch((err) => {
        setError(err.message);
        setIsLoading(false);
      });
  }, []);

  return (
    <main className="bg-white min-h-screen w-full p-8">
      <h1 className="text-2xl font-bold text-perficient-dark mb-6">Todos</h1>

      {isLoading && (
        <p className="text-gray-500" role="status" aria-busy="true">Loading todos...</p>
      )}

      {error && (
        <p className="text-red-600" role="alert">Error: {error}</p>
      )}

      {!isLoading && !error && (
        <ul className="space-y-2">
          {todos.map((todo) => (
            <li key={todo.id} className="flex items-center gap-2 p-2 border rounded">
              <input type="checkbox" checked={todo.completed} readOnly />
              <span className={todo.completed ? 'line-through text-gray-400' : 'text-gray-800'}>
                {todo.title}
              </span>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
