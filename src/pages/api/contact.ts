import type { APIRoute } from 'astro';
import { Buffer } from 'node:buffer';

const MAILGUN_ENDPOINT = 'https://api.mailgun.net/v3';

const isValidEmail = (value: string): boolean => {
	return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
};

const trimValue = (value: FormDataEntryValue | null): string => {
	if (!value) return '';
	return String(value).trim();
};

/** Static build probes this route with GET; the form only accepts POST. */
export const GET: APIRoute = () =>
	new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
		status: 405,
		headers: {
			Allow: 'POST',
			'Content-Type': 'application/json',
		},
	});

export const POST: APIRoute = async ({ request, redirect }) => {
	const formData = await request.formData();

	const name = trimValue(formData.get('name'));
	const email = trimValue(formData.get('email'));
	const company = trimValue(formData.get('company'));
	const website = trimValue(formData.get('website'));
	const message = trimValue(formData.get('message'));
	const honeypot = trimValue(formData.get('company_site'));

	if (honeypot) {
		return redirect('/contact?status=success');
	}

	if (!name || !email || !message) {
		return redirect('/contact?status=invalid');
	}

	if (!isValidEmail(email)) {
		return redirect('/contact?status=invalid');
	}

	const apiKey = import.meta.env.MAILGUN_API_KEY;
	const domain = import.meta.env.MAILGUN_DOMAIN;
	const toEmail = import.meta.env.MAILGUN_TO_EMAIL;
	const fromEmail = import.meta.env.MAILGUN_FROM_EMAIL;

	if (!apiKey || !domain || !toEmail || !fromEmail) {
		console.error('Mailgun environment variables are not fully configured.');
		return redirect('/contact?status=error');
	}

	const outbound = new URLSearchParams();
	outbound.set('from', fromEmail);
	outbound.set('to', toEmail);
	outbound.set('subject', `New website lead from ${name}`);
	outbound.set(
		'text',
		[
			`Name: ${name}`,
			`Email: ${email}`,
			`Company: ${company || 'Not provided'}`,
			`Website: ${website || 'Not provided'}`,
			'',
			'Message:',
			message,
		].join('\n')
	);
	outbound.set('h:Reply-To', email);

	try {
		const response = await fetch(`${MAILGUN_ENDPOINT}/${domain}/messages`, {
			method: 'POST',
			headers: {
				Authorization: `Basic ${Buffer.from(`api:${apiKey}`).toString('base64')}`,
				'Content-Type': 'application/x-www-form-urlencoded',
			},
			body: outbound.toString(),
		});

		if (!response.ok) {
			const body = await response.text();
			console.error('Mailgun send failed', response.status, body);
			return redirect('/contact?status=error');
		}

		return redirect('/contact?status=success');
	} catch (error) {
		console.error('Contact form send exception', error);
		return redirect('/contact?status=error');
	}
};
