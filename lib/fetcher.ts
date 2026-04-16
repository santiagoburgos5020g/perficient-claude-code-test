export class FetchError extends Error {
  status: number;
  info: unknown;

  constructor(message: string, status: number, info: unknown) {
    super(message);
    this.status = status;
    this.info = info;
  }
}

const fetcher = async (url: string) => {
  const res = await fetch(url);
  if (!res.ok) {
    const info = await res.json().catch(() => null);
    throw new FetchError(`Fetch error: ${res.status}`, res.status, info);
  }
  return res.json();
};

export default fetcher;
