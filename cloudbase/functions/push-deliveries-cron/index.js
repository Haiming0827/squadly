function required(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

exports.main = async () => {
  const url = required('PUSH_WORKER_URL');
  if (!url.startsWith('https://')) throw new Error('Invalid push worker URL');
  const secret = required('PUSH_WORKER_SECRET');
  if (secret.length < 32) throw new Error('Invalid push worker secret');
  const apiKey = required('CLOUDBASE_APIKEY');

  const result = await fetch(url, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${apiKey}`,
      'x-squadly-worker-secret': secret,
    },
  });
  if (!result.ok) throw new Error(`Push worker returned ${result.status}`);
  return result.json();
};
