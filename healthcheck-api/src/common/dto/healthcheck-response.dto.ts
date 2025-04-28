export class HealthcheckResponseDto {
  status!: 'ok' | 'error';
  timestamp!: string;
  services!: Record<string, 'ok' | 'error'>;
}
