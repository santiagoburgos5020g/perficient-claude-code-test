import { useState, useEffect } from 'react';

interface User {
  id: number;
  name: string;
  username: string;
  email: string;
  phone: string;
  website: string;
  company: { name: string };
}

export default function TestReview333Page() {
  const [users, setUsers] = useState<User[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch('https://jsonplaceholder.typicode.com/users')
      .then((res) => {
        if (!res.ok) throw new Error(`Failed to fetch users (${res.status})`);
        return res.json();
      })
      .then((data: User[]) => {
        setUsers(data);
        setIsLoading(false);
      })
      .catch((err: Error) => {
        setError(err.message);
        setIsLoading(false);
      });
  }, []);

  return (
    <div className="bg-white min-h-screen w-full p-8">
      <h1 className="text-2xl font-bold text-perficient-dark mb-6">Hello 123</h1>

      {isLoading && <p className="text-gray-500">Loading users...</p>}

      {error && <p className="text-red-600">Error: {error}</p>}

      {!isLoading && !error && (
        <ul className="space-y-4">
          {users.map((user) => (
            <li
              key={user.id}
              className="border border-gray-200 rounded p-4"
            >
              <p className="font-bold text-perficient-dark">{user.name}</p>
              <p className="text-sm text-perficient-dark/70">@{user.username}</p>
              <p className="text-sm text-perficient-dark/70">{user.email}</p>
              <p className="text-sm text-perficient-dark/70">{user.phone}</p>
              <p className="text-sm text-perficient-dark/70">{user.company.name}</p>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
