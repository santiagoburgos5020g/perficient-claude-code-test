import { useEffect, useState } from 'react';

interface Todo {
  userId: number;
  id: number;
  title: string;
  completed: boolean;
}

export default function TestR1() {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch('https://jsonplaceholder.typicode.com/todos')
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then((data: Todo[]) => {
        setTodos(data);
        setIsLoading(false);
      })
      .catch((err: Error) => {
        setError(err.message);
        setIsLoading(false);
      });
  }, []);

  if (isLoading) {
    return (
      <div className="flex justify-center items-center min-h-screen bg-white">
        <p className="text-gray-500 text-lg">Loading todos...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex justify-center items-center min-h-screen bg-white">
        <p className="text-red-500 text-lg">Error: {error}</p>
      </div>
    );
  }

  return (
    <div className="bg-white min-h-screen w-full p-8">
      <h1 className="text-2xl font-bold mb-6">Todos ({todos.length})</h1>
      <ul className="space-y-2">
        {todos.map((todo) => (
          <li
            key={todo.id}
            className="flex items-center gap-3 p-3 border border-gray-200 rounded"
          >
            <span
              className={`w-3 h-3 rounded-full ${todo.completed ? 'bg-green-500' : 'bg-red-400'}`}
            />
            <span className={todo.completed ? 'line-through text-gray-400' : 'text-gray-800'}>
              {todo.title}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}
