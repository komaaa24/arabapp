import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { User } from '../users/user.entity';
import { UsersService } from '../users/users.service';
import { GoogleAuthDto } from './dto/google-auth.dto';
import { GoogleTokenService } from './google-token.service';

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly googleTokenService: GoogleTokenService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async googleLogin(dto: GoogleAuthDto) {
    const payload = await this.googleTokenService.verifyIdToken(dto.token);

    if (!payload.sub || !payload.email) {
      throw new UnauthorizedException('Google token missing required claims');
    }

    if (payload.email_verified === false) {
      throw new UnauthorizedException('Google account email is not verified');
    }

    const user = await this.usersService.upsertGoogleUser({
      googleId: payload.sub,
      email: payload.email,
      name: payload.name ?? null,
      avatar: payload.picture ?? null,
    });

    const accessToken = await this.jwtService.signAsync({
      sub: user.id,
      email: user.email,
    });

    return {
      access_token: accessToken,
      token_type: 'Bearer',
      expires_in: this.configService.get<string>('JWT_EXPIRES_IN', '15m'),
      user: this.serializeUser(user),
    };
  }

  async me(userId: number) {
    const user = await this.usersService.findById(userId);
    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    return this.serializeUser(user);
  }

  private serializeUser(user: User) {
    return {
      id: user.id,
      email: user.email,
      name: user.name,
      avatar: user.avatar,
      created_at: user.createdAt,
    };
  }
}
