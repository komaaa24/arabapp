import { TokenPayload } from 'google-auth-library';

export interface GooglePayload extends TokenPayload {
  sub: string;
  email: string;
  name?: string;
  picture?: string;
  email_verified?: boolean;
}
