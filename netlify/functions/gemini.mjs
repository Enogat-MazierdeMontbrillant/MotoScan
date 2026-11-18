const model = 'gemini-3.5-flash-lite';

export default async (request) => {
  if (request.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return Response.json({ error: 'GEMINI_API_KEY is not configured.' }, { status: 503 });
  }

  let body;
  try {
    body = await request.json();
  } catch (error) {
    if (error instanceof SyntaxError) {
      return Response.json({ error: 'Invalid JSON body.' }, { status: 400 });
    }
    throw error;
  }
  if (!body || !Array.isArray(body.contents)) {
    return Response.json({ error: 'Invalid Gemini request.' }, { status: 400 });
  }

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: JSON.stringify(body),
    },
  );
  return new Response(await response.text(), {
    status: response.status,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
};
