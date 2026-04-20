import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './user.entity';

interface GoogleUserInput {
  googleId: string;
  email: string;
  name?: string | null;
  avatar?: string | null;
}

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly usersRepository: Repository<User>,
  ) {}

  findById(id: number): Promise<User | null> {
    return this.usersRepository.findOne({ where: { id } });
  }

  findByGoogleId(googleId: string): Promise<User | null> {
    return this.usersRepository.findOne({ where: { googleId } });
  }

  findByEmail(email: string): Promise<User | null> {
    return this.usersRepository.findOne({ where: { email } });
  }

  async upsertGoogleUser(input: GoogleUserInput): Promise<User> {
    const existingByGoogleId = await this.findByGoogleId(input.googleId);
    if (existingByGoogleId) {
      existingByGoogleId.email = input.email;
      existingByGoogleId.name = input.name ?? existingByGoogleId.name;
      existingByGoogleId.avatar = input.avatar ?? existingByGoogleId.avatar;
      return this.usersRepository.save(existingByGoogleId);
    }

    const existingByEmail = await this.findByEmail(input.email);
    if (existingByEmail) {
      existingByEmail.googleId = input.googleId;
      existingByEmail.name = input.name ?? existingByEmail.name;
      existingByEmail.avatar = input.avatar ?? existingByEmail.avatar;
      return this.usersRepository.save(existingByEmail);
    }

    const user = this.usersRepository.create({
      googleId: input.googleId,
      email: input.email,
      name: input.name ?? null,
      avatar: input.avatar ?? null,
    });

    return this.usersRepository.save(user);
  }
}
