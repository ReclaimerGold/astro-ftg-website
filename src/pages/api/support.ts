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

const formatRequestType = (requestType: string): string => {
	if (requestType === 'technical-support') return 'Technical support';
	if (requestType === 'design-update') return 'Design update';
	if (requestType === 'both') return 'Technical support + design update';
	return requestType;
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
	const requestType = trimValue(formData.get('request_type'));
	const priority = trimValue(formData.get('priority')) || 'normal';
	const pageUrl = trimValue(formData.get('page_url'));
	const message = trimValue(formData.get('message'));
	const honeypot = trimValue(formData.get('company_site'));

	if (honeypot) {
		return redirect('/support?status=success');
	}

	if (!name || !email || !requestType || !message) {
		return redirect('/support?status=invalid');
	}

	if (!isValidEmail(email)) {
		return redirect('/support?status=invalid');
	}

	const apiKey = import.meta.env.MAILGUN_API_KEY;
	const domain = import.meta.env.MAILGUN_DOMAIN;
	const toEmail = import.meta.env.MAILGUN_TO_EMAIL;
	const fromEmail = import.meta.env.MAILGUN_FROM_EMAIL;

	if (!apiKey || !domain || !toEmail || !fromEmail) {
		console.error('Mailgun environment variables are not fully configured.');
		return redirect('/support?status=error');
	}

	const outbound = new URLSearchParams();
	outbound.set('from', fromEmail);
	outbound.set('to', toEmail);
	outbound.set('subject', `New support request from ${name}`);
	outbound.set(
		'text',
		[
			`Name: ${name}`,
			`Email: ${email}`,
			`Business: ${company || 'Not provided'}`,
			`Request type: ${formatRequestType(requestType) || 'Not provided'}`,
			`Priority: ${priority}`,
			`Affected URL: ${pageUrl || 'Not provided'}`,
			'',
			'Request details:',
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
			console.error('Mailgun support send failed', response.status, body);
			return redirect('/support?status=error');
		}

		return redirect('/support?status=success');
	} catch (error) {
		console.error('Support form send exception', error);
		return redirect('/support?status=error');
	}
};
