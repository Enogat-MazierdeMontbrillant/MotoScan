export default async (request) => {
  if (request.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const apiKey = process.env.NINJAS_API_KEY;
  if (!apiKey) {
    return Response.json({ error: 'NINJAS_API_KEY is not configured.' }, { status: 503 });
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
  if (
    !body ||
    typeof body.make !== 'string' ||
    !body.make.trim() ||
    typeof body.model !== 'string' ||
    !body.model.trim() ||
    (body.year !== undefined && !/^\d{4}$/.test(body.year))
  ) {
    return Response.json({ error: 'Invalid motorcycle search.' }, { status: 400 });
  }

  const url = new URL('https://api.api-ninjas.com/v1/motorcycles');
  url.searchParams.set('make', body.make.trim());
  url.searchParams.set('model', body.model.trim());
  if (body.year) url.searchParams.set('year', body.year);

  const response = await fetch(url, { headers: { 'X-Api-Key': apiKey } });
  return new Response(await response.text(), {
    status: response.status,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
};
